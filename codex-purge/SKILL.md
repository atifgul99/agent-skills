---
name: codex-purge
description: >
  Audit and purge Codex local history under ~/.codex to reclaim disk space or remove old thread history
  without breaking auth, config, memories, installed plugins, or personal skills. Use when the user mentions
  deleting Codex history, purging old Codex sessions, shrinking ~/.codex, cleaning old rollouts, or resetting
  local Codex history. Always audit first, show a dry run, then execute the requested age threshold and category.
---

# Codex History Purge

Codex stores history in both files and SQLite databases. A safe purge must handle both:

- Rollout JSONL files in `~/.codex/sessions/` and `~/.codex/archived_sessions/`
- Thread metadata in `~/.codex/state_5.sqlite`
- Prompt history in `~/.codex/history.jsonl`
- Recent-session index in `~/.codex/session_index.jsonl`
- Per-thread logs in `~/.codex/logs_2.sqlite`
- Optional thread-goal rows in `~/.codex/goals_1.sqlite`

Do not delete only the rollout files. That leaves broken rows in SQLite and stale recents.

## Workflow

### Step 1 — Audit

```bash
bash ~/.codex/skills/codex-purge/scripts/audit.sh
```

Read the output carefully. Focus on:

- Total footprint of `~/.codex`
- Size of `sessions/`, `archived_sessions/`, `logs_2.sqlite`, and `state_5.sqlite`
- Age breakdown for thread history
- How many thread rows, rollout files, history entries, and log rows are older than the requested threshold

### Step 2 — Decide the retention window and depth

Use these categories:

1. `Histories only` — old rollouts, thread metadata, history lines, session index rows, old per-thread logs
2. `+ Auxiliary runtime artifacts` — category 1 plus old files in `shell_snapshots/`, `.tmp/`, `log/`, `browser/`, `computer-use/`, `backups/`, `ambient-suggestions/`
3. `+ Generated outputs` — category 2 plus old files in `generated_images/`
4. `+ Plugin download cache` — category 3 plus old files in `plugins/cache/`

Use category `1` by default unless the user explicitly asks for a deeper cleanup.

Age values can be:

- bare integer like `10` for days
- explicit days like `10d`
- explicit hours like `6h`
- `all`

### Step 3 — Dry run

```bash
bash ~/.codex/skills/codex-purge/scripts/purge.sh \
  --age <age_or_all> \
  --categories <1|2|3|4> \
  --dry-run
```

Examples:

```bash
# Delete Codex histories older than 10 days
bash ~/.codex/skills/codex-purge/scripts/purge.sh --age 10 --categories 1 --dry-run

# Delete everything older than 6 hours
bash ~/.codex/skills/codex-purge/scripts/purge.sh --age 6h --categories 4 --dry-run

# Delete everything older than 30 days except plugin cache
bash ~/.codex/skills/codex-purge/scripts/purge.sh --age 30 --categories 3 --dry-run

# Delete all old history plus all optional caches
bash ~/.codex/skills/codex-purge/scripts/purge.sh --age all --categories 4 --dry-run
```

### Step 4 — Execute

Run the same command with `--yes` and without `--dry-run`:

```bash
bash ~/.codex/skills/codex-purge/scripts/purge.sh \
  --age <age_or_all> \
  --categories <1|2|3|4> \
  --yes
```

If the user wants safety copies of Codex config first, add `--backup`.

### Step 5 — Re-audit

Run the audit again and confirm:

- Remaining thread counts
- Remaining old-thread count for the threshold
- Updated disk usage

## What this skill never touches without explicit direction

- `~/.codex/auth.json`
- `~/.codex/config.toml`
- `~/.codex/memories/`
- `~/.codex/skills/`
- `~/.codex/plugins/` except optional cache files in category `4`
- `~/.codex/rules/`
- `~/.codex/hooks/`
- `~/.codex/automations/`
- `~/.codex/AGENTS.md`

## Notes

- `logs_2.sqlite` may have no old rows even when old threads exist. That is normal.
- `state_5.sqlite` is the authoritative thread catalog. Purge rows there along with rollout files.
- The script checkpoints WAL files after deletion, but it does not run a full `VACUUM`. Full compaction is better done while Codex is closed.
