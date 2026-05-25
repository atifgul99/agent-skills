#!/usr/bin/env bash
# Purge Claude Code data with age-based and category-based filtering.
# Compatible with bash 3.2+ (macOS default).
#
# Usage:
#   purge.sh --age <days|all> --categories <1|2|3|4> [--dry-run] [--yes] [--backup]
#
# --age: keep sessions newer than N days; "all" means purge everything
# --categories:
#   1 = transcripts only (session .jsonl files, history.jsonl)
#   2 = transcripts + auxiliary caches (debug, telemetry, shell-snapshots,
#       paste-cache, session-env, tasks, todos, backups, file-history)
#   3 = level 2 + stats-cache.json, statsig/ (everything EXCEPT plugin marketplace)
#   4 = everything above + plugin marketplace cache

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
AGE_DAYS=""
CATEGORIES=""
DRY_RUN=false
AUTO_YES=false
BACKUP=false

# Parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --age) AGE_DAYS="$2"; shift 2 ;;
    --categories) CATEGORIES="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes|-y) AUTO_YES=true; shift ;;
    --backup) BACKUP=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$AGE_DAYS" ] || [ -z "$CATEGORIES" ]; then
  echo "Usage: purge.sh --age <days|all> --categories <1|2|3|4> [--dry-run] [--yes] [--backup]"
  exit 1
fi

DRY_PREFIX=""
if $DRY_RUN; then DRY_PREFIX="[DRY RUN] "; fi

log() { echo "${DRY_PREFIX}$*"; }

# ------------------------------------------------------------------
# Helpers: build file lists into temp files (bash 3.2 compatible)
# ------------------------------------------------------------------

TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_WORK"' EXIT

SESSION_LIST="$TMPDIR_WORK/sessions.txt"
SESSIONDIR_LIST="$TMPDIR_WORK/session_dirs.txt"

build_session_list() {
  if [ "$AGE_DAYS" = "all" ]; then
    find "$CLAUDE_DIR/projects" -name "*.jsonl" -not -path "*/memory/*" -type f 2>/dev/null \
      > "$SESSION_LIST"
  else
    find "$CLAUDE_DIR/projects" -name "*.jsonl" -not -path "*/memory/*" -type f \
      -mtime "+${AGE_DAYS}" 2>/dev/null \
      > "$SESSION_LIST"
  fi
}

build_session_dir_list() {
  if [ "$AGE_DAYS" = "all" ]; then
    find "$CLAUDE_DIR/projects" -mindepth 2 -maxdepth 2 -type d \
      -not -name "memory" 2>/dev/null \
      > "$SESSIONDIR_LIST"
  else
    find "$CLAUDE_DIR/projects" -mindepth 2 -maxdepth 2 -type d \
      -not -name "memory" -mtime "+${AGE_DAYS}" 2>/dev/null \
      > "$SESSIONDIR_LIST"
  fi
}

count_lines() { wc -l < "$1" 2>/dev/null | tr -d ' '; }

size_of_list() {
  local f="$1"
  local c
  c=$(count_lines "$f")
  if [ "$c" -gt 0 ]; then
    xargs du -ch < "$f" 2>/dev/null | tail -1 | cut -f1
  else
    echo "0B"
  fi
}

dir_size() {
  if [ -d "$1" ]; then
    du -sh "$1" 2>/dev/null | cut -f1
  else
    echo "0B"
  fi
}

dir_file_count() {
  if [ -d "$1" ]; then
    find "$1" -type f 2>/dev/null | wc -l | tr -d ' '
  else
    echo "0"
  fi
}

# ------------------------------------------------------------------
# Build lists first
# ------------------------------------------------------------------

build_session_list
build_session_dir_list

SESSION_COUNT=$(count_lines "$SESSION_LIST")
SESSION_SIZE=$(size_of_list "$SESSION_LIST")
SESSIONDIR_COUNT=$(count_lines "$SESSIONDIR_LIST")

# ------------------------------------------------------------------
# Backup
# ------------------------------------------------------------------

if $BACKUP && ! $DRY_RUN; then
  BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$BACKUP_DIR"
  cp "$HOME/.claude.json" "$BACKUP_DIR/" 2>/dev/null && log "Backed up ~/.claude.json"
  cp "$CLAUDE_DIR/settings.json" "$BACKUP_DIR/" 2>/dev/null && log "Backed up settings.json"
  cp "$CLAUDE_DIR/CLAUDE.md" "$BACKUP_DIR/" 2>/dev/null && log "Backed up CLAUDE.md"
  log "Backup saved to: $BACKUP_DIR"
  echo ""
fi

# ------------------------------------------------------------------
# Show plan
# ------------------------------------------------------------------

echo "============================================"
echo " ${DRY_PREFIX}Purge Plan"
echo " Age threshold: ${AGE_DAYS} days  (deletes sessions older than this)"
echo " Category level: $CATEGORIES"
echo "============================================"
echo ""

echo "=== CATEGORY 1: Session transcripts ==="
log "  Session .jsonl files: $SESSION_COUNT files  ($SESSION_SIZE)"
log "  Session data dirs: $SESSIONDIR_COUNT dirs (versioned file snapshots in projects/)"

if [ -f "$CLAUDE_DIR/history.jsonl" ]; then
  history_size=$(du -sh "$CLAUDE_DIR/history.jsonl" 2>/dev/null | cut -f1)
  history_total=$(wc -l < "$CLAUDE_DIR/history.jsonl" 2>/dev/null | tr -d ' ')
  if [ "$AGE_DAYS" = "all" ]; then
    history_keep=0
    history_drop=$history_total
  else
    history_keep=$(python3 -c "
import json, sys, time
cutoff = time.time() - (${AGE_DAYS} * 86400)
keep = 0
with open('$CLAUDE_DIR/history.jsonl') as f:
    for line in f:
        line = line.strip()
        if not line: continue
        try:
            ts = json.loads(line).get('timestamp', 0)
            if ts > 1e12: ts /= 1000
            if ts >= cutoff: keep += 1
        except: pass
print(keep)
" 2>/dev/null || echo "?")
    history_drop=$(( history_total - history_keep ))
  fi
  log "  history.jsonl: $history_total entries, $history_size — will trim to $history_keep (drop $history_drop older than ${AGE_DAYS} days)"
else
  log "  history.jsonl: not present"
fi
echo ""

if [ "$CATEGORIES" -ge 2 ]; then
  echo "=== CATEGORY 2: Auxiliary caches ==="
  for dir in file-history debug telemetry shell-snapshots paste-cache session-env tasks todos backups; do
    if [ -d "$CLAUDE_DIR/$dir" ]; then
      log "  $dir/: $(dir_size "$CLAUDE_DIR/$dir")  ($(dir_file_count "$CLAUDE_DIR/$dir") files)"
    fi
  done
  echo ""
fi

if [ "$CATEGORIES" -ge 3 ]; then
  echo "=== CATEGORY 3: Stats / feature-flag caches ==="
  [ -f "$CLAUDE_DIR/stats-cache.json" ] && \
    log "  stats-cache.json: $(du -sh "$CLAUDE_DIR/stats-cache.json" 2>/dev/null | cut -f1)  (resets /usage counters)"
  [ -d "$CLAUDE_DIR/statsig" ] && \
    log "  statsig/: $(dir_size "$CLAUDE_DIR/statsig")"
  echo ""
fi

if [ "$CATEGORIES" -ge 4 ]; then
  echo "=== CATEGORY 4: Plugin marketplace cache ==="
  for dir in plugins/marketplaces plugins/cache; do
    if [ -d "$CLAUDE_DIR/$dir" ]; then
      log "  $dir/: $(dir_size "$CLAUDE_DIR/$dir")  (re-fetched automatically on next plugin sync)"
    fi
  done
  echo ""
fi

echo "=== WILL PRESERVE ==="
log "  ~/.claude.json (auth, OAuth tokens)"
log "  settings.json, settings.local.json"
log "  CLAUDE.md (global instructions)"
log "  plugins/local/, plugins/installed_plugins.json"
log "  skills/, commands/, agents/, rules/"
log "  projects/*/memory/ (all persistent memory)"
echo ""

# ------------------------------------------------------------------
# Confirm
# ------------------------------------------------------------------

if ! $DRY_RUN; then
  if ! $AUTO_YES; then
    printf "Proceed with purge? [y/N] "
    read -r confirm
    case "$confirm" in
      [Yy]*) ;;
      *) echo "Aborted."; exit 0 ;;
    esac
  fi
fi

# ------------------------------------------------------------------
# Execute
# ------------------------------------------------------------------

if ! $DRY_RUN; then
  echo "Executing purge..."
  echo ""
fi

# Category 1: Session .jsonl files
if [ "$SESSION_COUNT" -gt 0 ]; then
  if $DRY_RUN; then
    log "Would delete $SESSION_COUNT session transcript files"
  else
    xargs rm -f < "$SESSION_LIST" 2>/dev/null || true
    log "Deleted $SESSION_COUNT session transcript files"
  fi
fi

# Category 1: Session data dirs inside projects/
if [ "$SESSIONDIR_COUNT" -gt 0 ]; then
  if $DRY_RUN; then
    log "Would delete $SESSIONDIR_COUNT session data dirs"
  else
    xargs rm -rf < "$SESSIONDIR_LIST" 2>/dev/null || true
    log "Deleted $SESSIONDIR_COUNT session data dirs"
  fi
fi

# Clean up empty project-level dirs (only when purging all, and only if no memory/)
if ! $DRY_RUN && [ "$AGE_DAYS" = "all" ]; then
  find "$CLAUDE_DIR/projects" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r pdir; do
    mem_files=0
    if [ -d "$pdir/memory" ]; then
      mem_files=$(find "$pdir/memory" -mindepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    fi
    remaining=$(find "$pdir" -not -path "$pdir/memory" -not -path "$pdir/memory/*" \
      -mindepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$remaining" -eq 0 ] && [ "$mem_files" -eq 0 ]; then
      rm -rf "$pdir" 2>/dev/null || true
    fi
  done
fi

# Category 1: history.jsonl — trim by age, or delete entirely if age=all
if [ -f "$CLAUDE_DIR/history.jsonl" ]; then
  if [ "$AGE_DAYS" = "all" ]; then
    if $DRY_RUN; then
      log "Would delete history.jsonl (all entries)"
    else
      rm -f "$CLAUDE_DIR/history.jsonl" && log "Deleted history.jsonl"
    fi
  else
    HISTORY_TMP="$TMPDIR_WORK/history_trimmed.jsonl"
    python3 -c "
import json, sys, time
cutoff = time.time() - (${AGE_DAYS} * 86400)
kept = dropped = 0
with open('$CLAUDE_DIR/history.jsonl') as f, open('$HISTORY_TMP', 'w') as out:
    for line in f:
        line_s = line.strip()
        if not line_s:
            continue
        try:
            ts = json.loads(line_s).get('timestamp', 0)
            if ts > 1e12: ts /= 1000
            if ts >= cutoff:
                out.write(line)
                kept += 1
            else:
                dropped += 1
        except:
            out.write(line)
            kept += 1
print(f'kept={kept} dropped={dropped}')
" 2>/dev/null > "$TMPDIR_WORK/history_result.txt"
    result=$(cat "$TMPDIR_WORK/history_result.txt" 2>/dev/null || echo "kept=? dropped=?")
    if $DRY_RUN; then
      log "Would trim history.jsonl: $result"
    else
      cp "$HISTORY_TMP" "$CLAUDE_DIR/history.jsonl" && log "Trimmed history.jsonl: $result"
    fi
  fi
fi

# Category 2: Auxiliary caches
if [ "$CATEGORIES" -ge 2 ]; then
  for dir in file-history debug telemetry shell-snapshots paste-cache session-env tasks todos backups; do
    if [ -d "$CLAUDE_DIR/$dir" ]; then
      if $DRY_RUN; then
        log "Would clear $dir/"
      else
        find "$CLAUDE_DIR/$dir" -mindepth 1 -delete 2>/dev/null || true
        log "Cleared $dir/"
      fi
    fi
  done
fi

# Category 3: Stats caches (everything except plugin marketplace)
if [ "$CATEGORIES" -ge 3 ]; then
  if [ -f "$CLAUDE_DIR/stats-cache.json" ]; then
    if $DRY_RUN; then
      log "Would delete stats-cache.json"
    else
      rm -f "$CLAUDE_DIR/stats-cache.json" && log "Deleted stats-cache.json"
    fi
  fi
  if [ -d "$CLAUDE_DIR/statsig" ]; then
    if $DRY_RUN; then
      log "Would clear statsig/"
    else
      find "$CLAUDE_DIR/statsig" -mindepth 1 -delete 2>/dev/null || true
      log "Cleared statsig/"
    fi
  fi
fi

# Category 4: Plugin marketplace cache
if [ "$CATEGORIES" -ge 4 ]; then
  for dir in plugins/marketplaces plugins/cache; do
    if [ -d "$CLAUDE_DIR/$dir" ]; then
      if $DRY_RUN; then
        log "Would clear $dir/"
      else
        find "$CLAUDE_DIR/$dir" -mindepth 1 -delete 2>/dev/null || true
        log "Cleared $dir/"
      fi
    fi
  done
fi

echo ""
echo "============================================"
if $DRY_RUN; then
  echo " Dry run complete. Nothing was deleted."
  echo ""
  echo " To execute, re-run without --dry-run."
else
  echo " Purge complete."
  echo ""
  new_size=$(du -sh "$CLAUDE_DIR" 2>/dev/null | cut -f1)
  remaining=$(find "$CLAUDE_DIR/projects" -name "*.jsonl" -not -path "*/memory/*" -type f 2>/dev/null | wc -l | tr -d ' ')
  echo " New total size: $new_size"
  echo " Sessions remaining: $remaining"
fi
echo "============================================"
