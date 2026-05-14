---
name: notebooklm
description: Complete API for Google NotebookLM - full programmatic access including features not in the web UI. Create notebooks, add sources (URLs, YouTube, PDFs, audio, video, images), run web research, generate all artifact types (podcasts, videos, slides, quizzes, reports, infographics, mind maps), and download in multiple formats. Activates on explicit /notebooklm or intent like "create a podcast about X", "research and write an article", "turn these URLs into a slide deck".
---

# NotebookLM Automation

Complete programmatic access to Google NotebookLM—including capabilities not exposed in the web UI. Create notebooks, add sources (URLs, YouTube, PDFs, audio, video, images), chat with content, run deep web research, generate all artifact types, and download results in multiple formats.

## Prerequisites

**IMPORTANT:** Before using any command, you MUST authenticate:

```bash
notebooklm login          # Opens browser for Google OAuth
notebooklm list           # Verify authentication works
```

If commands fail with authentication errors, re-run `notebooklm login`.

### CI/CD, Multiple Accounts, and Parallel Agents

| Variable | Purpose |
|----------|---------|
| `NOTEBOOKLM_HOME` | Custom config directory (default: `~/.notebooklm`) |
| `NOTEBOOKLM_AUTH_JSON` | Inline auth JSON - no file writes needed |

**Parallel agents:** Use explicit `-n <notebook_id>` flags instead of `notebooklm use` to prevent context conflicts.

## Agent Setup Verification

Before starting workflows, verify the CLI is ready:

1. `notebooklm status` → Should show "Authenticated as: email@..."
2. `notebooklm list --json` → Should return valid JSON
3. If either fails → Run `notebooklm login`

## When This Skill Activates

**Explicit:** User says "/notebooklm", "use notebooklm", or mentions the tool by name

**Intent detection:** Recognize requests like:
- "Create a podcast about [topic]"
- "Summarize these URLs/documents"
- "Generate a quiz from my research"
- "Research [topic] and write an article"
- "Turn these sources into a slide deck"
- "Create flashcards for studying"
- "Generate a video explainer"
- "Make an infographic"
- "Create a mind map of the concepts"
- "Add these sources to NotebookLM"
- "Research this topic and post to social media"

## Autonomy Rules

**Run automatically (no confirmation):**
- `notebooklm status` / `notebooklm auth check`
- `notebooklm list` / `notebooklm source list` / `notebooklm artifact list`
- `notebooklm language list` / `notebooklm language get` / `notebooklm language set`
- `notebooklm artifact wait` / `notebooklm source wait` / `notebooklm research wait` (in subagent)
- `notebooklm use <id>` (single-agent only)
- `notebooklm create` / `notebooklm ask "..."` / `notebooklm history`
- `notebooklm source add`

**Ask before running:**
- `notebooklm delete` — destructive
- `notebooklm generate *` — long-running, may fail
- `notebooklm download *` — writes to filesystem
- `notebooklm ask "..." --save-as-note` / `notebooklm history --save`

## Quick Reference

| Task | Command |
|------|---------|
| Authenticate | `notebooklm login` |
| Diagnose auth | `notebooklm auth check` |
| List notebooks | `notebooklm list` |
| Create notebook | `notebooklm create "Title"` |
| Set context | `notebooklm use <notebook_id>` |
| Show context | `notebooklm status` |
| Add URL source | `notebooklm source add "https://..."` |
| Add file | `notebooklm source add ./file.pdf` |
| Add YouTube | `notebooklm source add "https://youtube.com/..."` |
| Add Google Drive | `notebooklm source add-drive "https://docs.google.com/..."` |
| List sources | `notebooklm source list` |
| Delete source by ID | `notebooklm source delete <source_id>` |
| Delete source by title | `notebooklm source delete-by-title "Exact Title"` |
| Wait for source | `notebooklm source wait <source_id>` |
| Web research (fast) | `notebooklm source add-research "query"` |
| Web research (deep) | `notebooklm source add-research "query" --mode deep --no-wait` |
| Check research status | `notebooklm research status` |
| Wait for research | `notebooklm research wait --import-all` |
| Chat | `notebooklm ask "question"` |
| Chat (with citations) | `notebooklm ask "question" --json` |
| Chat (specific sources) | `notebooklm ask "question" -s src_id1 -s src_id2` |
| Chat (save as note) | `notebooklm ask "question" --save-as-note` |
| Show history | `notebooklm history` |
| Save history as note | `notebooklm history --save` |
| Get source fulltext | `notebooklm source fulltext <source_id>` |
| Get source guide | `notebooklm source guide <source_id>` |
| Generate podcast | `notebooklm generate audio "instructions"` |
| Generate video | `notebooklm generate video "instructions"` |
| Generate slide deck | `notebooklm generate slide-deck` |
| Generate report | `notebooklm generate report --format briefing-doc` |
| Generate quiz | `notebooklm generate quiz` |
| Generate flashcards | `notebooklm generate flashcards` |
| Generate infographic | `notebooklm generate infographic` |
| Generate mind map | `notebooklm generate mind-map` |
| Generate data table | `notebooklm generate data-table "description"` |
| Revise a slide | `notebooklm generate revise-slide "prompt" --artifact <id> --slide 0` |
| Check artifact status | `notebooklm artifact list` |
| Wait for artifact | `notebooklm artifact wait <artifact_id>` |
| Download audio | `notebooklm download audio ./output.mp3` |
| Download video | `notebooklm download video ./output.mp4` |
| Download slides (PDF) | `notebooklm download slide-deck ./slides.pdf` |
| Download slides (PPTX) | `notebooklm download slide-deck ./slides.pptx --format pptx` |
| Download report | `notebooklm download report ./report.md` |
| Download mind map | `notebooklm download mind-map ./map.json` |
| Download quiz (JSON) | `notebooklm download quiz quiz.json` |
| Download quiz (MD) | `notebooklm download quiz --format markdown quiz.md` |
| Download flashcards | `notebooklm download flashcards cards.json` |
| Download data table | `notebooklm download data-table ./data.csv` |
| List languages | `notebooklm language list` |
| Set language | `notebooklm language set zh_Hans` |

**Parallel safety:** Use explicit `-n <notebook_id>` in parallel workflows instead of `notebooklm use`.

## Generation Types

All generate commands support:
- `-s, --source` to use specific source(s)
- `--language` to set output language
- `--json` for machine-readable output (returns `task_id`)
- `--retry N` to retry on rate limits

| Type | Command | Options | Download |
|------|---------|---------|----------|
| Podcast | `generate audio` | `--format [deep-dive\|brief\|critique\|debate]`, `--length [short\|default\|long]` | .mp3 |
| Video | `generate video` | `--format [explainer\|brief]`, `--style [auto\|classic\|whiteboard\|kawaii\|anime\|watercolor\|retro-print\|heritage\|paper-craft]` | .mp4 |
| Slide Deck | `generate slide-deck` | `--format [detailed\|presenter]`, `--length [default\|short]` | .pdf / .pptx |
| Slide Revision | `generate revise-slide "prompt" --artifact <id> --slide N` | `--wait`, `--notebook` | re-downloads parent deck |
| Infographic | `generate infographic` | `--orientation [landscape\|portrait\|square]`, `--detail [concise\|standard\|detailed]`, `--style [auto\|sketch-note\|professional\|bento-grid\|editorial\|instructional\|bricks\|clay\|anime\|kawaii\|scientific]` | .png |
| Report | `generate report` | `--format [briefing-doc\|study-guide\|blog-post\|custom]`, `--append "extra instructions"` | .md |
| Mind Map | `generate mind-map` | sync, instant | .json |
| Data Table | `generate data-table "description"` | description required | .csv |
| Quiz | `generate quiz` | `--difficulty [easy\|medium\|hard]`, `--quantity [fewer\|standard\|more]` | .json/.md/.html |
| Flashcards | `generate flashcards` | `--difficulty [easy\|medium\|hard]`, `--quantity [fewer\|standard\|more]` | .json/.md/.html |

## Features Beyond the Web UI

| Feature | Command | Description |
|---------|---------|-------------|
| **Batch downloads** | `download <type> --all` | Download all artifacts of a type at once |
| **Quiz/Flashcard export** | `download quiz --format json` | Export as JSON, Markdown, or HTML |
| **Mind map extraction** | `download mind-map` | Export hierarchical JSON |
| **Data table export** | `download data-table` | Download as CSV |
| **Slide deck as PPTX** | `download slide-deck --format pptx` | Editable .pptx (web UI only offers PDF) |
| **Slide revision** | `generate revise-slide "prompt" --artifact <id> --slide N` | Modify individual slides |
| **Report template append** | `generate report --format study-guide --append "..."` | Custom instructions on top of templates |
| **Source fulltext** | `source fulltext <id>` | Retrieve indexed text of any source |
| **Save chat to note** | `ask "..." --save-as-note` | Save Q&A as notebook note |
| **Programmatic sharing** | `share` commands | Manage sharing without UI |
| **Deep web research** | `source add-research "query" --mode deep` | 20+ sources auto-imported |

## Common Workflows

### Research to Podcast (with Subagent)

1. `notebooklm create "Research: [topic]"`
2. `notebooklm source add "https://url1.com"` (repeat for each)
3. Wait for sources: check `notebooklm source list --json` until all `status=ready`
4. `notebooklm generate audio "Focus on [angle]" --json` → note `artifact_id`
5. Spawn background subagent:
   ```
   Task(prompt="Wait for artifact {artifact_id} in notebook {notebook_id}.
   Run: notebooklm artifact wait {artifact_id} -n {notebook_id} --timeout 1200
   Then: notebooklm download audio ./podcast.mp3 -a {artifact_id} -n {notebook_id}")
   ```

### Research → Article Pipeline

When user wants to research a topic and produce a polished article:

1. Create notebook: `notebooklm create "Research: [topic]"`
2. Add sources or run deep research:
   ```bash
   notebooklm source add-research "[topic]" --mode deep --no-wait
   notebooklm research wait --import-all --timeout 1800
   ```
3. Ask synthesizing questions and save answers as notes:
   ```bash
   notebooklm ask "What are the key findings across all sources?" --save-as-note --note-title "Key Findings"
   notebooklm ask "What are the main arguments and counterarguments?" --save-as-note --note-title "Arguments"
   notebooklm ask "What are the practical implications?" --save-as-note --note-title "Implications"
   ```
4. Generate a blog-post report:
   ```bash
   notebooklm generate report --format blog-post --append "Write for a professional audience. Include citations."
   notebooklm download report ./article.md
   ```
5. Hand the `./article.md` to Claude for final polish and formatting

### Research → Social Posts Pipeline

When user wants to turn research into social media content:

1. Create notebook and add sources (URLs, PDFs, or deep research)
2. Ask targeted questions for each platform:
   ```bash
   notebooklm ask "Summarize the 3 most surprising insights in 2 sentences each" --save-as-note
   notebooklm ask "What is the single most shareable takeaway from this research?" --save-as-note
   notebooklm ask "List 5 key statistics or facts from the sources" --save-as-note
   ```
3. Generate a briefing doc for reference:
   ```bash
   notebooklm generate report --format briefing-doc
   notebooklm download report ./briefing.md
   ```
4. Use the notes + briefing as input for Claude to write platform-specific posts (Threads, LinkedIn, Twitter/X, Instagram)

### Trend → Content Pipeline

When user wants to discover trending topics and create content:

1. Identify trending topic (user provides or Claude searches)
2. Run deep research to gather sources:
   ```bash
   notebooklm create "Trend: [topic]"
   notebooklm source add-research "[topic] latest developments 2026" --mode deep --no-wait
   notebooklm research wait --import-all --timeout 1800
   ```
3. Generate multiple content formats in parallel (use subagents):
   - Subagent 1: `notebooklm generate report --format blog-post`
   - Subagent 2: `notebooklm generate audio "Create an engaging deep-dive podcast"`
   - Subagent 3: `notebooklm generate slide-deck`
4. Download all when complete
5. Claude synthesizes and polishes for publishing

### Bulk Import

1. `notebooklm create "Collection: [name]"`
2. Add sources with `--json` to capture IDs:
   ```bash
   notebooklm source add "https://url1.com" --json
   notebooklm source add "https://url2.com" --json
   notebooklm source add ./local-file.pdf --json
   ```
3. Spawn background subagent to wait for all source IDs to be ready
4. Chat or generate once sources are `ready`

**Source limits:** Standard: 50, Plus: 100, Pro: 300, Ultra: 600 sources per notebook.
**Supported types:** PDFs, YouTube, web URLs, Google Docs, text, Markdown, Word docs, audio, video, images.

### Document Analysis

1. `notebooklm create "Analysis: [project]"`
2. `notebooklm source add ./doc.pdf`
3. `notebooklm ask "Summarize the key points"`
4. `notebooklm ask "What are the main arguments?"` — continues conversation
5. `notebooklm generate mind-map` for visual overview (instant, no wait needed)

## Command Output Formats

Commands with `--json` return structured data:

**Create notebook:** `{"id": "abc123...", "title": "Research"}`

**Add source:** `{"source_id": "def456...", "title": "Example", "status": "processing"}`

**Generate artifact:** `{"task_id": "xyz789...", "status": "pending"}`

**Chat with references:**
```json
{"answer": "X is... [1] [2]", "conversation_id": "...", "references": [{"source_id": "...", "citation_number": 1, "cited_text": "Relevant passage..."}]}
```

**List:** `{"notebooks": [{"id": "...", "title": "...", "created_at": "..."}]}`

**Source list:** `{"sources": [{"id": "...", "title": "...", "status": "ready|processing|error"}]}`

**Artifact list:** `{"artifacts": [{"id": "...", "title": "...", "type": "Audio Overview", "status": "pending|in_progress|completed|unknown"}]}`

## Subagent Pattern for Long Operations

Use this pattern for generation and source waiting to keep the main conversation non-blocking:

```
Task(
  prompt="Wait for artifact {artifact_id} in notebook {notebook_id} to complete, then download.
          Use: notebooklm artifact wait {artifact_id} -n {notebook_id} --timeout 600
          Then: notebooklm download audio ./podcast.mp3 -a {artifact_id} -n {notebook_id}
          Report success or failure.",
  subagent_type="general-purpose"
)
```

## Error Handling

| Error | Cause | Action |
|-------|-------|--------|
| Auth/cookie error | Session expired | `notebooklm auth check` then `notebooklm login` |
| "No notebook context" | Context not set | Use `-n <id>` flag or `notebooklm use <id>` |
| "No result found for RPC ID" | Rate limiting | Wait 5-10 min, retry |
| `GENERATION_FAILED` | Google rate limit | Wait and retry later |
| Download fails | Generation incomplete | Check `artifact list` for status |
| RPC protocol error | Google changed APIs | `pip install --upgrade notebooklm-py` |

## Processing Times

| Operation | Typical | Timeout |
|-----------|---------|---------|
| Source processing | 30s - 10 min | 600s |
| Research (fast) | 30s - 2 min | 180s |
| Research (deep) | 15 - 30+ min | 1800s |
| Mind-map | instant | n/a |
| Quiz, flashcards | 5 - 15 min | 900s |
| Report, data-table | 5 - 15 min | 900s |
| Audio generation | 10 - 20 min | 1200s |
| Video generation | 15 - 45 min | 2700s |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (not found, processing failed) |
| 2 | Timeout (wait commands only) |

## Language Configuration

Language is a **global** setting affecting all notebooks.

```bash
notebooklm language list              # 80+ supported languages
notebooklm language get               # Current setting
notebooklm language set zh_Hans       # Simplified Chinese
notebooklm generate audio --language ja  # Override per command
```

## Troubleshooting

```bash
notebooklm auth check          # Diagnose auth issues
notebooklm auth check --test   # Full validation with network test
notebooklm --version           # Check installed version
pip install --upgrade notebooklm-py  # Update to latest
notebooklm skill install       # Update skill file
```

**Reliable operations:** Notebooks CRUD, source add/list/delete, chat, mind-map, report, data-table.

**May hit rate limits:** Audio, video, quiz, flashcards, infographic, slide deck. Retry after 5-10 min.
