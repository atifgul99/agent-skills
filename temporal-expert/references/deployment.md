# Temporal Deployment Reference

## Table of Contents

1. [Local Development](#local-development)
2. [Temporal Cloud](#temporal-cloud)
3. [Self-Hosted Docker Compose](#self-hosted-docker-compose)
4. [Worker Dockerization](#worker-dockerization)
5. [Hostinger VPS Deployment](#hostinger-vps-deployment)
6. [CI/CD with GitHub Actions](#cicd-with-github-actions)
7. [Environment Variables](#environment-variables)
8. [Monitoring & Ops](#monitoring--ops)

---

## Local Development

### Temporal CLI Dev Server

```bash
# Install Temporal CLI
brew install temporal  # macOS
curl -sSf https://temporal.download/cli.sh | sh  # Linux

# Start local dev server (in-memory, no persistence)
temporal server start-dev

# gRPC: localhost:7233
# Web UI: localhost:8233
```

### Docker Compose (Local with Persistence)

```bash
git clone https://github.com/temporalio/docker-compose.git
cd docker-compose
docker compose up -d
```

Default stack: PostgreSQL + Temporal Server + Web UI. Ports: 7233 (gRPC), 8233 (Web UI).

---

## Temporal Cloud

Fully managed. No server to run — only deploy workers.

### Setup Steps

1. Create account at https://cloud.temporal.io
2. Create namespace (e.g., `postbuzz-prod`)
3. Choose auth method:
   - **API Key** (simpler): Generate in Cloud UI → Settings → API Keys
   - **mTLS** (more secure): Generate certificate pair, upload public cert to Cloud

### Connection Config (TypeScript)

```typescript
import { Client, Connection } from '@temporalio/client'

// API Key auth
const connection = await Connection.connect({
  address: 'postbuzz-prod.tmprl.cloud:7233',
  tls: true,
  metadata: {
    'temporal-namespace': 'postbuzz-prod',
  },
  apiKey: process.env.TEMPORAL_API_KEY,
})

// mTLS auth
import { readFileSync } from 'fs'

const connection = await Connection.connect({
  address: 'postbuzz-prod.tmprl.cloud:7233',
  tls: {
    clientCertPair: {
      crt: readFileSync(process.env.TEMPORAL_TLS_CERT!),
      key: readFileSync(process.env.TEMPORAL_TLS_KEY!),
    },
  },
})

const client = new Client({ connection, namespace: 'postbuzz-prod' })
```

### Worker Connection (NativeConnection)

```typescript
import { NativeConnection, Worker } from '@temporalio/worker'

const connection = await NativeConnection.connect({
  address: process.env.TEMPORAL_ADDRESS!,
  tls: true,
  metadata: { 'temporal-namespace': process.env.TEMPORAL_NAMESPACE! },
  apiKey: process.env.TEMPORAL_API_KEY,
})

const worker = await Worker.create({
  connection,
  namespace: process.env.TEMPORAL_NAMESPACE!,
  taskQueue: 'post-processing',
  workflowsPath: require.resolve('./workflows'),
  activities,
})
```

### Cloud Pricing (as of 2026)

- Free tier: $0 for first 5M actions/month (sufficient for early stage)
- Standard: $25/month base + $0.042 per 1K actions beyond free tier
- Actions = workflow tasks, activity tasks, signals, queries, heartbeats

---

## Self-Hosted Docker Compose

For staging/testing environments or budget-constrained self-hosting.

### Minimal Production Stack

```yaml
# docker-compose.temporal.yml
services:
  postgresql:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: temporal
      POSTGRES_PASSWORD: ${TEMPORAL_DB_PASSWORD}
      POSTGRES_DB: temporal
    volumes:
      - temporal-db:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U temporal"]
      interval: 10s
      timeout: 5s
      retries: 5

  temporal:
    image: temporalio/auto-setup:latest
    depends_on:
      postgresql:
        condition: service_healthy
    environment:
      - DB=postgres12
      - DB_PORT=5432
      - POSTGRES_USER=temporal
      - POSTGRES_PWD=${TEMPORAL_DB_PASSWORD}
      - POSTGRES_SEEDS=postgresql
      - DYNAMIC_CONFIG_FILE_PATH=/etc/temporal/config/dynamicconfig.yaml
    ports:
      - "7233:7233"
    volumes:
      - ./temporal-config/dynamicconfig.yaml:/etc/temporal/config/dynamicconfig.yaml
    restart: unless-stopped

  temporal-ui:
    image: temporalio/ui:latest
    depends_on:
      - temporal
    environment:
      - TEMPORAL_ADDRESS=temporal:7233
      - TEMPORAL_CORS_ORIGINS=http://localhost:3000
    ports:
      - "8233:8080"
    restart: unless-stopped

volumes:
  temporal-db:
```

### Dynamic Config

```yaml
# temporal-config/dynamicconfig.yaml
# Minimal safe defaults
system.forceSearchAttributesCacheRefreshOnRead:
  - value: true
limit.maxIDLength:
  - value: 255
```

### Resource Requirements

| Component | Min RAM | Recommended RAM |
|-----------|---------|-----------------|
| PostgreSQL | 512 MB | 1 GB |
| Temporal Server | 512 MB | 1–2 GB |
| Temporal UI | 128 MB | 256 MB |
| **Total** | **~1.2 GB** | **~3 GB** |

IMPORTANT: Temporal Server should NOT be exposed to the public internet. Treat it like a database
— restrict access to your internal network or VPN.

---

## Worker Dockerization

### Dockerfile (TypeScript Worker)

```dockerfile
FROM node:22-alpine AS builder

WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable && pnpm install --frozen-lockfile
COPY tsconfig.json ./
COPY src/temporal ./src/temporal
RUN pnpm exec tsc --project tsconfig.worker.json

FROM node:22-alpine AS runner

WORKDIR /app
RUN corepack enable
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY package.json ./

# Temporal SDK requires native modules
RUN apk add --no-cache libc6-compat

USER node
CMD ["node", "dist/temporal/worker.js"]
```

### Worker tsconfig

```json
// tsconfig.worker.json
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "outDir": "./dist",
    "rootDir": "./src"
  },
  "include": ["src/temporal/**/*"]
}
```

### Docker Compose Worker Service

```yaml
# Add to your existing docker-compose.yml
temporal-worker:
  build:
    context: .
    dockerfile: Dockerfile.worker
  env_file: .env
  environment:
    TEMPORAL_ADDRESS: ${TEMPORAL_ADDRESS}
    TEMPORAL_NAMESPACE: ${TEMPORAL_NAMESPACE}
    TEMPORAL_API_KEY: ${TEMPORAL_API_KEY}
    NODE_ENV: production
  restart: unless-stopped
  deploy:
    resources:
      limits:
        memory: 512M
  healthcheck:
    test: ["CMD", "node", "-e", "process.exit(0)"]
    interval: 30s
    timeout: 10s
    retries: 3
```

---

## Hostinger VPS Deployment

Architecture: Workers on Hostinger VPS → Temporal Cloud (no self-hosted server on VPS).

### Prerequisites

- VPS: 2 vCPU / 8 GB RAM / 100 GB disk (e.g., Hostinger KVM 2)
- Ubuntu 24.04 with Docker
- Existing workloads (e.g., n8n) — monitor combined RAM with `docker stats`

### Deployment Steps

```bash
# SSH into VPS
ssh root@<vps-ip>

# Create worker directory
mkdir -p /opt/temporal-worker

# Clone or copy worker code
git clone <your-repo> /opt/temporal-worker
# or: scp -r ./temporal-worker root@<vps-ip>:/opt/temporal-worker

# Create .env (never commit this)
cat > /opt/temporal-worker/.env << 'EOF'
TEMPORAL_ADDRESS=postbuzz-prod.tmprl.cloud:7233
TEMPORAL_NAMESPACE=postbuzz-prod
TEMPORAL_API_KEY=<your-api-key>
NODE_ENV=production
EOF

# Add worker to existing docker-compose or create standalone
cd /opt/temporal-worker
docker compose up -d --build

# Verify worker connects
docker compose logs -f temporal-worker
# Should see: "Worker started, polling task queue: post-processing"
```

### Resource Budget (8 GB VPS)

| Service | RAM | Notes |
|---------|-----|-------|
| n8n | ~1.5 GB | Existing |
| Temporal Worker | ~512 MB | Node.js worker |
| OS + Docker | ~1 GB | Base overhead |
| **Headroom** | **~5 GB** | Buffer for spikes |

If workers need more resources, scale horizontally (multiple worker containers) or upgrade VPS.

---

## CI/CD with GitHub Actions

```yaml
# .github/workflows/deploy-worker.yml
name: Deploy Temporal Worker

on:
  push:
    branches: [main]
    paths:
      - 'src/temporal/**'
      - 'Dockerfile.worker'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker image
        run: docker build -f Dockerfile.worker -t temporal-worker:${{ github.sha }} .

      - name: Save and transfer image
        run: |
          docker save temporal-worker:${{ github.sha }} | gzip > worker.tar.gz
          scp worker.tar.gz ${{ secrets.VPS_USER }}@${{ secrets.VPS_HOST }}:/tmp/

      - name: Deploy to VPS
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            docker load < /tmp/worker.tar.gz
            cd /opt/temporal-worker
            docker compose up -d --force-recreate temporal-worker
            rm /tmp/worker.tar.gz
```

Alternative: Use a container registry (GHCR, Docker Hub) to avoid `docker save/load`.

---

## Environment Variables

### Required (Worker + Client)

| Variable | Example | Description |
|----------|---------|-------------|
| `TEMPORAL_ADDRESS` | `postbuzz-prod.tmprl.cloud:7233` | Temporal server gRPC endpoint |
| `TEMPORAL_NAMESPACE` | `postbuzz-prod` | Namespace name |

### Auth (pick one)

| Variable | Description |
|----------|-------------|
| `TEMPORAL_API_KEY` | API key for Temporal Cloud |
| `TEMPORAL_TLS_CERT` | Path to mTLS client certificate |
| `TEMPORAL_TLS_KEY` | Path to mTLS client private key |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `TEMPORAL_TASK_QUEUE` | `default` | Default task queue name |
| `TEMPORAL_MAX_CONCURRENT_ACTIVITIES` | `100` | Max parallel activities per worker |
| `TEMPORAL_MAX_CONCURRENT_WORKFLOWS` | `200` | Max parallel workflow tasks per worker |

---

## Monitoring & Ops

### Health Checks

- Worker appears as connected in Temporal Cloud UI → Namespaces → Workers
- `temporal workflow list --namespace postbuzz-prod` — lists running workflows
- `docker compose logs -f temporal-worker` — watch worker output

### Alerting (Temporal Cloud)

- Worker disconnect alerts (Cloud UI → Settings → Alerts)
- Workflow failure rate thresholds
- Task queue backlog (scheduleToStart latency > threshold)

### Log Rotation (VPS)

```yaml
# In docker-compose.yml, for each service:
temporal-worker:
  logging:
    driver: json-file
    options:
      max-size: "50m"
      max-file: "5"
```

### Useful CLI Commands

```bash
# List workflows
temporal workflow list -n postbuzz-prod

# Describe a workflow
temporal workflow describe -w publish-post-ws123-post456 -n postbuzz-prod

# Show workflow history
temporal workflow show -w publish-post-ws123-post456 -n postbuzz-prod

# Signal a workflow
temporal workflow signal -w <workflow-id> --name cancel -n postbuzz-prod

# Terminate a stuck workflow
temporal workflow terminate -w <workflow-id> --reason "stuck" -n postbuzz-prod
```
