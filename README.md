# Agent Skills

Shared source of truth for AI agent skills. Cursor, Claude Code, and Codex
discover these via symlinks from their respective user-level skill directories.

## Directory Layout

```
~/.agent-skills/                  # Shared skills (this directory)
├── README.md
├── brand-voice-ultimate/        # Brand voice analysis, extraction, enforcement
├── campaign-generator/          # Social media campaign generator (Segmind API)
├── composition-patterns/        # Vercel React composition patterns (compound components)
├── de-ai-ify/                   # Remove AI jargon, restore human voice
├── design-motion-principles/    # Motion and interaction design auditor
├── elite-frontend-ux/           # Bold aesthetic UX + systematic design tokens
├── engineering-skills/          # 21 engineering skills (alirezarezvani)
├── frontend-design/             # Anthropic official frontend design skill
├── marketing-skills/            # 32 marketing skills (coreyhaines31)
├── motion/                      # Motion (Framer Motion) — animations, gestures, LazyMotion
├── playwright-skill/            # Browser automation — screenshots, testing, validation
├── positioning-basics/          # Product positioning frameworks
├── remotion-best-practices/    # Remotion — video creation in React
├── t5-image-prompts/            # Image prompt engine + generator (7 modes)
├── temporal-expert/             # Temporal.io workflow orchestration
├── web-design-guidelines/       # Vercel 100+ UX/accessibility rules
└── README-pm-skills-archive.md  # Archive of removed PM skills (reinstall guide)

~/.cursor/skills-cursor/          # Cursor user-level discovery
├── create-rule/                  # Cursor builtin (real dir)
├── engineering-skills -> ~/.agent-skills/engineering-skills  # Shared (symlink)
└── ...

~/.claude/skills/                 # Claude Code user-level discovery
├── engineering-skills -> ~/.agent-skills/engineering-skills  # Shared (symlink)
└── ...

~/.codex/skills/                  # Codex user-level discovery
├── engineering-skills -> ~/.agent-skills/engineering-skills  # Shared (symlink)
└── ...

<project>/skills/                 # Project-specific source of truth
├── quality-gate/
├── security-audit/
└── ...

<project>/.cursor/skills/         # Symlinks to <project>/skills/
<project>/.claude/skills/         # Symlinks to <project>/skills/
<project>/.codex/skills/          # Symlinks to <project>/skills/
```

## Three Tiers

**Shared (user-level)** — Skills useful across any project and any tool.
Source of truth lives here in `~/.agent-skills/<name>/`. Symlinked into each
tool's user-level discovery path (`~/.cursor/skills-cursor/`, `~/.claude/skills/`,
`~/.codex/skills/`) — these are globally available across all projects.

**Project-specific** — Skills tied to a single project's codebase or domain.
Source of truth lives in `<project>/skills/`. Symlinked only within the project
into `<project>/.cursor/skills/`, `<project>/.claude/skills/`, and
`<project>/.codex/skills/`. These never cross into user-level skill directories.

**Tool-specific** — Skills that only make sense in one tool (e.g. Cursor's
`create-rule`). Stay as real directories in their tool's user-level or project
path — no symlinks needed.

## Quick Setup

To automatically create symlinks for all shared skills across all three tools:

```bash
~/.agent-skills/setup-symlinks.sh
```

This script:
- Enumerates all skills in `~/.agent-skills/`
- Creates symlinks in `~/.cursor/skills-cursor/`, `~/.claude/skills/`, and `~/.codex/skills/`
- **Fails safely** if any symlink already exists (prevents overwrites)

## How To

### Add a shared skill

```bash
# 1. Place the skill in the shared store
cp -r /path/to/new-skill ~/.agent-skills/new-skill

# 2. Symlink into each tool's discovery path
ln -s ~/.agent-skills/new-skill ~/.cursor/skills-cursor/new-skill
ln -s ~/.agent-skills/new-skill ~/.claude/skills/new-skill
ln -s ~/.agent-skills/new-skill ~/.codex/skills/new-skill
```

### Add a project-specific skill

Project skills are local to the project only. They do NOT symlink to or interact
with user-level skill directories.

```bash
# 1. Create in the project's skills/ directory (source of truth)
mkdir -p <project>/skills/new-skill
# Write SKILL.md

# 2. Symlink from tool discovery paths WITHIN the project only
ln -s ../../skills/new-skill <project>/.cursor/skills/new-skill
ln -s ../../skills/new-skill <project>/.claude/skills/new-skill
ln -s ../../skills/new-skill <project>/.codex/skills/new-skill
```

### Add a tool-specific skill

Place directly in the tool's user-level directory (no symlink):

```bash
# Cursor-only
cp -r /path/to/cursor-skill ~/.cursor/skills-cursor/cursor-skill

# Claude Code-only
cp -r /path/to/claude-skill ~/.claude/skills/claude-skill

# Codex-only
cp -r /path/to/codex-skill ~/.codex/skills/codex-skill
```

### Update a shared skill

Edit files in `~/.agent-skills/<name>/` directly. Symlinks resolve
automatically — Cursor, Claude Code, and Codex see the changes immediately.

### Remove a shared skill

```bash
# 1. Remove symlinks first
rm ~/.cursor/skills-cursor/skill-name
rm ~/.claude/skills/skill-name
rm ~/.codex/skills/skill-name

# 2. Remove the source
rm -rf ~/.agent-skills/skill-name
```

### Install a skill collection from GitHub

```bash
git clone https://github.com/user/repo /tmp/repo
cp -r /tmp/repo/skills/* ~/.agent-skills/
# Then create symlinks for each skill (see "Add a shared skill")
rm -rf /tmp/repo
```

## Conventions

- **Naming**: `lowercase-kebab-case`. Related skills share a prefix
  (e.g. `pm-product-strategy`, `pm-execution`).
- **Structure**: Each skill directory contains a `SKILL.md` with YAML
  frontmatter (`name`, `description`) followed by the instructions.
- **Groups**: A skill directory may contain sub-skill directories instead
  of a single `SKILL.md` (e.g. `engineering-skills/senior-frontend/SKILL.md`).
- **No duplication**: Never copy the same skill into multiple directories.
  Use symlinks from the appropriate source of truth instead.
