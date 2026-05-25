#!/usr/bin/env bash
# Audit ~/.claude/ and report sizes. Safe — read-only.

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

echo "============================================"
echo " Claude Code Storage Audit"
echo " Directory: $CLAUDE_DIR"
echo "============================================"
echo ""

echo "=== TOTAL SIZE ==="
du -sh "$CLAUDE_DIR" 2>/dev/null
echo ""

echo "=== TOP-LEVEL BREAKDOWN ==="
du -sh "$CLAUDE_DIR"/* "$CLAUDE_DIR"/.[!.]* 2>/dev/null | sort -hr | head -30
echo ""

echo "=== SESSION TRANSCRIPTS by project ==="
du -sh "$CLAUDE_DIR/projects"/*/  2>/dev/null | sort -hr | head -15
echo ""

echo "=== LARGEST SESSION FILES (top 10) ==="
find "$CLAUDE_DIR/projects" -name "*.jsonl" -not -path "*/memory/*" -type f 2>/dev/null \
  | xargs du -h 2>/dev/null | sort -hr | head -10
echo ""

echo "=== COUNTS ==="
total_sessions=$(find "$CLAUDE_DIR/projects" -name "*.jsonl" -not -path "*/memory/*" -type f 2>/dev/null | wc -l | tr -d ' ')
echo "Session transcript files: $total_sessions"

history_lines=$(wc -l < "$CLAUDE_DIR/history.jsonl" 2>/dev/null || echo 0)
echo "history.jsonl entries: $history_lines"

project_count=$(ls -d "$CLAUDE_DIR/projects"/*/ 2>/dev/null | wc -l | tr -d ' ')
echo "Projects tracked: $project_count"
echo ""

echo "=== AGE BREAKDOWN (sessions) ==="
for days in 1 7 14 30 60 90; do
  count=$(find "$CLAUDE_DIR/projects" -name "*.jsonl" -not -path "*/memory/*" -type f -mtime "+$days" 2>/dev/null | wc -l | tr -d ' ')
  size=$(find "$CLAUDE_DIR/projects" -name "*.jsonl" -not -path "*/memory/*" -type f -mtime "+$days" 2>/dev/null \
    | xargs du -ch 2>/dev/null | tail -1 | cut -f1)
  echo "  Older than $days days: $count files, ${size:-0B}"
done
count_all=$(find "$CLAUDE_DIR/projects" -name "*.jsonl" -not -path "*/memory/*" -type f 2>/dev/null | wc -l | tr -d ' ')
size_all=$(find "$CLAUDE_DIR/projects" -name "*.jsonl" -not -path "*/memory/*" -type f 2>/dev/null \
  | xargs du -ch 2>/dev/null | tail -1 | cut -f1)
echo "  All sessions: $count_all files, ${size_all:-0B}"
echo ""

echo "=== AUXILIARY CACHES ==="
for dir in file-history debug telemetry shell-snapshots paste-cache session-env tasks todos backups; do
  if [ -d "$CLAUDE_DIR/$dir" ]; then
    size=$(du -sh "$CLAUDE_DIR/$dir" 2>/dev/null | cut -f1)
    count=$(find "$CLAUDE_DIR/$dir" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  $dir/: $size ($count files)"
  fi
done
echo ""

echo "=== PLUGIN CACHE ==="
if [ -d "$CLAUDE_DIR/plugins/marketplaces" ]; then
  size=$(du -sh "$CLAUDE_DIR/plugins/marketplaces" 2>/dev/null | cut -f1)
  echo "  plugins/marketplaces/: $size (re-fetchable)"
fi
if [ -d "$CLAUDE_DIR/plugins/cache" ]; then
  size=$(du -sh "$CLAUDE_DIR/plugins/cache" 2>/dev/null | cut -f1)
  echo "  plugins/cache/: $size"
fi
echo ""

echo "=== MEMORY (DO NOT DELETE) ==="
find "$CLAUDE_DIR/projects" -type d -name "memory" 2>/dev/null | while read mdir; do
  size=$(du -sh "$mdir" 2>/dev/null | cut -f1)
  project=$(basename "$(dirname "$mdir")")
  echo "  $project/memory/: $size"
done
echo ""

echo "=== THIRD-PARTY SQLITE DATABASES ==="
found=0
for search_dir in "$HOME/.claude-memory" "$HOME/Library/Application Support/Claude" "$CLAUDE_DIR"; do
  while IFS= read -r -d '' f; do
    size=$(du -h "$f" 2>/dev/null | cut -f1)
    echo "  $f ($size)"
    found=1
  done < <(find "$search_dir" -type f \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \) -print0 2>/dev/null)
done
[ $found -eq 0 ] && echo "  None found."
echo ""

echo "=== CURRENT cleanupPeriodDays SETTING ==="
if [ -f "$CLAUDE_DIR/settings.json" ]; then
  days=$(python3 -c "import json,sys; d=json.load(open('$CLAUDE_DIR/settings.json')); print(d.get('cleanupPeriodDays','not set'))" 2>/dev/null || \
         grep -o '"cleanupPeriodDays":[[:space:]]*[0-9]*' "$CLAUDE_DIR/settings.json" | grep -o '[0-9]*$')
  echo "  cleanupPeriodDays: ${days:-not set} (default: 30)"
else
  echo "  settings.json not found"
fi
echo ""
echo "============================================"
echo " Audit complete."
echo "============================================"
