---
name: claude-purge
description: >
  Audit and purge Claude Code's local data (~/.claude/) to reclaim disk space, protect privacy,
  or get a clean slate — without breaking auth, settings, memory, or installed plugins.
  Invoke this skill whenever the user mentions: cleaning up Claude Code, deleting chat history,
  purging old sessions, "Claude is taking gigabytes", shrinking the .claude directory, resetting
  Claude Code state, disk usage related to Claude Code, or wanting to delete transcripts.
  Also surfaces third-party SQLite databases (memory MCPs, claude-vault) if found.
  Always audits first, asks two questions (age threshold + category depth), shows a dry-run
  summary, then executes only after confirmation. Never touches auth, settings, memory/, skills,
  or plugins without explicit direction.
---

# Claude Code Data Purge

## What lives in ~/.claude/ and what it costs

Based on a real audit of this machine's `~/.claude/`:

| Path                                                           | Typical size                | Safe to purge?                      |
| -------------------------------------------------------------- | --------------------------- | ----------------------------------- |
| `projects/*/session.jsonl`                                     | **GBs** — the main offender | Yes — by age                        |
| `projects/*/memory/`                                           | small                       | **NEVER** — your persistent memory  |
| `plugins/marketplaces/`                                        | 100s of MB                  | Yes — re-fetched automatically      |
| `file-history/`                                                | 100+ MB                     | Yes                                 |
| `debug/`                                                       | 10–100 MB                   | Yes                                 |
| `telemetry/`                                                   | 10–20 MB                    | Yes — stale failed-event queues     |
| `shell-snapshots/`                                             | a few MB                    | Yes                                 |
| `paste-cache/`, `session-env/`, `tasks/`, `todos/`, `backups/` | small                       | Yes                                 |
| `history.jsonl`                                                | ~1 MB                       | Yes — every prompt ever typed       |
| `stats-cache.json`                                             | tiny                        | Optional — resets `/usage` counters |
| `~/.claude.json`                                               | tiny                        | **NEVER** — auth + OAuth tokens     |
| `settings.json`, `CLAUDE.md`                                   | tiny                        | **NEVER** — your config             |
| `plugins/local/`, `skills/`, `commands/`                       | varies                      | **NEVER** — your custom content     |

## Workflow

Follow these five steps in order. Do not skip the audit or the dry run.

---

### Step 1 — Run the audit script

```bash
bash ~/.agent-skills/claude-purge/scripts/audit.sh
```

Read the output carefully. Note:

- Total size and what's taking the most space
- The "Age breakdown" table — it shows how many session files are older than 7/14/30/60/90 days
- Whether any `projects/*/memory/` directories exist (these must be preserved)
- Whether any third-party SQLite databases were found (bottom of report)

---

### Step 2 — Ask the user two questions

After showing the audit, ask these two questions. Do not assume defaults — always ask.

**Question A: How far back do you want to keep sessions?**

> "Session transcripts are the biggest item (~2.5 GB in your case). How far back do you want to keep them?"
>
> - Keep last **1 day** (delete anything older than 24 hours)
> - Keep last **7 days**
> - Keep last **14 days**
> - Keep last **30 days**
> - Keep last **60 days**
> - Keep last **90 days**
> - **Delete everything** (all sessions, regardless of age)

**Question B: How deep a clean?**

> "How thorough should the cleanup be?"
>
> 1. **Transcripts only** — session files and history.jsonl (safest, biggest wins)
> 2. **+ Auxiliary caches** — also clears debug/, telemetry/, shell-snapshots/, paste-cache/, file-history/, tasks/, todos/, backups/
> 3. **Everything except plugin cache** — level 2 + stats-cache.json (resets `/usage` counters) and statsig; plugins/marketplaces/ is left untouched
> 4. **Everything** — all of the above + plugin marketplace download cache (~330 MB); plugins still work but will re-download on next sync

If the user wants to **optionally back up** their settings first, offer `--backup` (saves `~/.claude.json`, `settings.json`, `CLAUDE.md` to a timestamped directory).

---

### Step 3 — Dry run

Before deleting anything, show exactly what will go:

```bash
bash ~/.agent-skills/claude-purge/scripts/purge.sh \
  --age <days_or_all> \
  --categories <1|2|3|4> \
  --dry-run
```

Examples:

```bash
# Keep last 1 day, transcripts + caches only
bash ~/.agent-skills/claude-purge/scripts/purge.sh --age 1 --categories 2 --dry-run

# Keep last 30 days, everything except plugin cache
bash ~/.agent-skills/claude-purge/scripts/purge.sh --age 30 --categories 3 --dry-run

# Delete all sessions, full nuke including plugin cache
bash ~/.agent-skills/claude-purge/scripts/purge.sh --age all --categories 4 --dry-run
```

Show the user the dry-run output and confirm they're happy with what will be removed.

---

### Step 4 — Execute

Once the user confirms, run without `--dry-run`. Add `--backup` if they asked for a safety copy:

```bash
bash ~/.agent-skills/claude-purge/scripts/purge.sh \
  --age <days_or_all> \
  --categories <1|2|3|4> \
  --yes \
  [--backup]
```

The script prints what it deleted and the new total size.

---

### Step 5 — Optional: lower cleanupPeriodDays

The built-in `cleanupPeriodDays` setting controls how long Claude Code keeps sessions before auto-deleting them. The default is 30 days; this machine is set to **90**. Lowering it prevents future buildup.

Suggest this after a purge:

> "To prevent this building up again, we can lower `cleanupPeriodDays`. Current value: 90. Recommended: 7–14 days. Want me to update `~/.claude/settings.json`?"

If yes:

```bash
# Read current settings, update cleanupPeriodDays, write back
python3 -c "
import json
path = '$HOME/.claude/settings.json'
with open(path) as f:
    s = json.load(f)
s['cleanupPeriodDays'] = 14
with open(path, 'w') as f:
    json.dump(s, f, indent=2)
print('cleanupPeriodDays set to 14')
"
```

`cleanupPeriodDays` affects: session `.jsonl` files, `file-history/`, `debug/`, `plans/`, `paste-cache/`, `image-cache/`, `session-env/`, `tasks/`, `shell-snapshots/`. It does NOT affect `history.jsonl` or `stats-cache.json`.

---

## Third-party SQLite databases

Claude Code itself does not use SQLite. If `audit.sh` finds any `.db` / `.sqlite` files:

| Common path                                 | What it is                               |
| ------------------------------------------- | ---------------------------------------- |
| `~/.claude-memory/memory.db`                | memory MCP server — knowledge graph      |
| `~/.claude/vault.db`                        | claude-vault — long-term session archive |
| `~/Library/Application Support/Claude/*.db` | Claude Desktop (separate product)        |

Inspect before deleting:

```bash
sqlite3 <path> ".tables"
sqlite3 <path> "SELECT COUNT(*) FROM <table>;"
```

Ask the user whether they want to keep each one. Deleting `memory.db` resets the knowledge graph; deleting `vault.db` removes the searchable archive.

---

## What this skill never touches (without explicit instruction)

- `~/.claude.json` — auth tokens
- `~/.claude/settings.json`, `settings.local.json`
- `~/.claude/CLAUDE.md`
- `~/.claude/plugins/local/`, `installed_plugins.json`
- `~/.claude/skills/`, `commands/`, `agents/`, `rules/`, `output-styles/`, `themes/`, `keybindings.json`
- `~/.claude/projects/*/memory/` — persistent memory for every project

If the user wants a full nuclear reset (remove everything and re-authenticate), tell them to run:

```bash
# Preserve auth + custom config, delete everything else
# Back up first!
cp ~/.claude.json ~/.claude.json.bak
cp ~/.claude/settings.json ~/settings.json.bak
# Then uninstall + reinstall Claude Code, or manually rm -rf ~/.claude
# and restore the backed-up files
```

Only do this if they explicitly ask — it requires re-authentication.
