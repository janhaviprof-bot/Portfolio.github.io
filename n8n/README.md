# Job discovery pipeline (n8n)

Self-hosted automation: collect jobs from ATS APIs + Gmail alerts into Google Sheets, then manually run ranking after you paste JDs and apply URLs.

## Workflows

| File | Trigger | Purpose |
|------|---------|---------|
| `workflows/workflow-a-daily-collect.json` | Schedule `0 7 * * *` (7 AM **America/New_York**) | ATS + Gmail → `jobs` tab + reminder email |
| `workflows/PipelineB.json` | **Manual only** | Read `unique_jobs` → rank 3 buckets → `ranked_*` tabs + apply email |
| `workflows/workflow-b-rank.json` | Same as `PipelineB.json` (generated) | Regenerate with `node scripts/build-workflow-b-rank.mjs` |

## Quick start

1. Copy `.env.example` → `.env` and fill values.
2. `docker compose up -d` (from this folder).
3. **Google Cloud:** enable Gmail + Sheets APIs, OAuth client, redirect URI — see `docs/credentials-and-permissions.md`.
4. Open n8n UI → connect **Gmail**, **Google Sheets**, and **OpenAI** credentials.
5. **Workflows → Import from File** → import both JSON files.
6. Create Google Sheet from `sheets/sheet-template.md`.
7. Set `SPREADSHEET_ID`, `REMINDER_EMAIL`, `SHEET_URL` (`.env` + workflow nodes).
8. Activate **Workflow A** only. Run **Workflow B** manually after you update the sheet.

See `docs/setup-checklist.md` for the full checklist. **Start here:** `docs/phase0-local-start.md`.

After editing Workflow B `code/*.js`, run `node scripts/build-workflow-b-rank.mjs` and re-import `workflows/PipelineB.json`.

## Credentials (you approve — not this repo)

| Service | How |
|---------|-----|
| Gmail + Sheets | Google Cloud OAuth → connect in n8n |
| OpenAI | API key in n8n Credentials (ranking only) |
| ATS boards | Public JSON — no keys for Tier 1 MVP |
| LinkedIn / Glassdoor | Email alerts only — no API keys |

Cursor and git never need access to your inbox or API keys.

## Daily routine

1. **7 AM** — Workflow A runs; check reminder email for Sheet link.
2. Open Sheet → filter `needs_manual_jd = TRUE` → paste `full_jd` + `apply_url` → `status = ready`.
3. n8n → **Workflow B** → **Execute workflow**.

## Code nodes

Copy scripts from `code/` into n8n Code nodes, or paste file contents when editing workflows.

## Compliance

- LinkedIn/Glassdoor: email parsing only — do not HTTP-fetch job detail pages.
- ATS: public JSON endpoints only (Greenhouse, Lever, Recruitee, Ashby, SmartRecruiters).
