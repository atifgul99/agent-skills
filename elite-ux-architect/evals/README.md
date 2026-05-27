# Evals

Baseline test set for `elite-ux-architect`. Six prompts spanning the four main
workflows (build, review, polish, redesign) plus two router-discipline cases
that specifically catch over-eager reference loading.

## Run

```bash
# All evals
./scripts/run-evals.sh

# One eval
./scripts/run-evals.sh 5
```

Each run writes to `evals/results/<timestamp>/eval-<id>-<name>/`:

- `stream.jsonl` — full `claude -p --output-format stream-json` transcript
- `loaded.txt` — every `references/NN-*.md` the agent actually `Read`
- `grade.json` — precision / recall vs `expected_loads`, plus missing / extra sets

A `summary.json` rolls up mean precision, mean recall, and perfect-router count.

## What we're measuring

**Router discipline.** Did the agent load only the references it needed? The
two pure-discipline evals (5 and 6) exist to catch the failure mode where the
skill greedily reads every file regardless of task — wasted tokens and
diffused attention.

We are **not** auto-grading output quality. That requires either an LLM
grader or human review (`generate_review.py` from skill-creator). What this
runner does cheaply and deterministically is verify the loading contract:
"Review code" loads `10+06+11` and _only_ `02/03/04` when those categories
actually apply.

## Fixtures

`fixtures/*.tsx` are tiny seeded files. Each contains a documented mix of
issues at every severity, often including a calibration trap (e.g. a button
with no explicit focus styles AND no `outline-none`, which an over-eager
reviewer will falsely flag as Critical).
