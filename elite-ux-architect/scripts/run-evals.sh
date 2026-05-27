#!/usr/bin/env bash
# run-evals.sh — invoke each eval in evals/evals.json via `claude -p`, capture
# which references/*.md files the model actually Read, and diff against
# `expected_loads`. Produces a router-discipline report.
#
# Requires: claude CLI, jq.
# Usage:   ./scripts/run-evals.sh [eval_id]   # one eval, or all if omitted

set -euo pipefail

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVALS_FILE="$SKILL_ROOT/evals/evals.json"
RESULTS_DIR="$SKILL_ROOT/evals/results/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

command -v jq >/dev/null || { echo "ERROR: jq required" >&2; exit 2; }
command -v claude >/dev/null || { echo "ERROR: claude CLI required" >&2; exit 2; }

ONLY_ID="${1:-}"

run_one() {
  local id=$1
  local name prompt expected fixtures
  name=$(jq -r ".evals[] | select(.id==$id) | .name" "$EVALS_FILE")
  prompt=$(jq -r ".evals[] | select(.id==$id) | .prompt" "$EVALS_FILE")
  expected=$(jq -r ".evals[] | select(.id==$id) | .expected_loads | join(\",\")" "$EVALS_FILE")
  fixtures=$(jq -r ".evals[] | select(.id==$id) | .files[]?" "$EVALS_FILE")

  local out_dir="$RESULTS_DIR/eval-$id-$name"
  mkdir -p "$out_dir"

  # Build the full prompt: invoke the skill, point at fixture if any
  local full_prompt="/elite-ux-architect $prompt"
  if [ -n "$fixtures" ]; then
    for f in $fixtures; do
      full_prompt="$full_prompt
Fixture file: $SKILL_ROOT/evals/$f"
    done
  fi

  echo "▶ Eval $id ($name)" >&2
  echo "  Expected loads: $expected" >&2

  # Run headless, stream-json gives us tool_use events to grep
  claude -p --output-format stream-json --verbose \
    --add-dir "$SKILL_ROOT" \
    "$full_prompt" \
    > "$out_dir/stream.jsonl" 2> "$out_dir/stderr.log" || {
      echo "  ⚠ claude exited non-zero (see $out_dir/stderr.log)" >&2
    }

  # Extract every Read tool call targeting references/
  # stream-json emits one JSON object per line; tool_use lives under .message.content[].
  jq -r '
    select(.type=="assistant")
    | .message.content[]?
    | select(.type=="tool_use" and .name=="Read")
    | .input.file_path
  ' "$out_dir/stream.jsonl" 2>/dev/null \
    | grep -oE 'references/[0-9]{2}[a-z]?-[a-z0-9-]+\.md' \
    | sort -u > "$out_dir/loaded.txt" || true

  # Compute precision/recall vs expected_loads
  local loaded_ids
  loaded_ids=$(sed -E 's|references/([0-9]{2}[a-z]?)-.*|\1|' "$out_dir/loaded.txt" | sort -u | paste -sd, -)

  python3 - "$expected" "$loaded_ids" <<'PY' > "$out_dir/grade.json"
import json, sys
expected = set(filter(None, sys.argv[1].split(',')))
loaded = set(filter(None, sys.argv[2].split(',')))
missing = sorted(expected - loaded)
extra = sorted(loaded - expected)
correct = sorted(expected & loaded)
result = {
  "expected": sorted(expected),
  "loaded": sorted(loaded),
  "correct": correct,
  "missing": missing,
  "extra_unexpected": extra,
  "precision": (len(correct) / len(loaded)) if loaded else 0,
  "recall": (len(correct) / len(expected)) if expected else 0,
}
print(json.dumps(result, indent=2))
PY

  jq -r '"  ✓ correct: \(.correct | join(\",\"))   ✗ missing: \(.missing | join(\",\"))   + extra: \(.extra_unexpected | join(\",\"))   precision=\(.precision) recall=\(.recall)"' "$out_dir/grade.json" >&2
}

if [ -n "$ONLY_ID" ]; then
  run_one "$ONLY_ID"
else
  for id in $(jq -r '.evals[].id' "$EVALS_FILE"); do
    run_one "$id"
  done
fi

# Aggregate
echo "" >&2
echo "── Summary ──" >&2
jq -s '
  {
    n: length,
    mean_precision: (map(.precision) | add / length),
    mean_recall:    (map(.recall)    | add / length),
    perfect_router: (map(select(.missing==[] and .extra_unexpected==[])) | length)
  }
' "$RESULTS_DIR"/eval-*/grade.json | tee "$RESULTS_DIR/summary.json" >&2

echo "" >&2
echo "Results: $RESULTS_DIR" >&2
