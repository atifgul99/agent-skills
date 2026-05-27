#!/usr/bin/env bash
# check-references.sh — validate every `references/NN-*.md` mention in the skill
# resolves to an actual file. Run from the skill root or anywhere; uses the
# script's own location to find the skill.
#
# Exits 1 on broken references, 0 on clean.

set -euo pipefail

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REFS_DIR="$SKILL_ROOT/references"

if [ ! -d "$REFS_DIR" ]; then
  echo "ERROR: references/ not found at $REFS_DIR" >&2
  exit 2
fi

# Build the set of existing reference basenames (e.g. "01-persona-and-principles.md")
existing=$(ls "$REFS_DIR" | sort -u)

# Find every mention of `references/<file>.md` or bare `<NN[a-z]?-...>.md` inside
# SKILL.md + references/*.md. Capture the basename, dedupe, then check each.
mentioned=$(
  grep -rohE '(references/)?[0-9]{2}[a-z]?-[a-z0-9-]+\.md' \
    "$SKILL_ROOT/SKILL.md" "$REFS_DIR" 2>/dev/null \
  | sed 's|^references/||' \
  | sort -u
)

broken=0
for ref in $mentioned; do
  if ! grep -qxF "$ref" <<<"$existing"; then
    echo "BROKEN: $ref is referenced but does not exist in references/"
    broken=$((broken + 1))
  fi
done

# Reverse check: every reference file should be mentioned somewhere
orphaned=0
for f in $existing; do
  if ! grep -qF "$f" <<<"$mentioned"; then
    echo "ORPHAN: references/$f exists but is never referenced from SKILL.md or another reference"
    orphaned=$((orphaned + 1))
  fi
done

if [ $broken -eq 0 ] && [ $orphaned -eq 0 ]; then
  echo "OK: $(echo "$existing" | wc -l | tr -d ' ') references, all linked"
  exit 0
fi

echo ""
echo "Summary: $broken broken, $orphaned orphaned"
exit 1
