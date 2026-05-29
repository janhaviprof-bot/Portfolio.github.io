# Phase 0 — local start

## 1. Google Sheet

1. Create a spreadsheet with tabs: `jobs`, `companies`, `config`, `archive` (see `sheets/sheet-template.md`).
2. Copy your Spreadsheet ID into `n8n/.env` as `SPREADSHEET_ID` and `SHEET_URL`.
3. Fill the `config` tab (title references, `title_similarity_threshold`, `openai_model`).

## 2. Google Cloud OAuth

Follow [credentials-and-permissions.md](credentials-and-permissions.md).

For **local** Docker, add this redirect URI in Google Cloud:

```
http://localhost:5678/rest/oauth2-credential/callback
```

## 3. Start n8n

**Prerequisite:** `docker version` must show **Server** without errors. If you get `500 Internal Server Error`, see [docker-troubleshooting.md](docker-troubleshooting.md).

```powershell
cd n8n
docker compose up -d
```

Open http://localhost:5678

## 4. Credentials in n8n UI

1. **Google Sheets OAuth2** — connect account.
2. **Gmail OAuth2** — same account as job alerts.
3. Confirm `.env` has `OPENAI_API_KEY` (Workflow B uses `$env.OPENAI_API_KEY`).

## 5. Import workflows

1. **Workflows → Import from File**
2. Import `workflows/workflow-a-daily-collect.json`
3. Import `workflows/workflow-b-bucket-rank.json`
4. On each Gmail/Sheets node, select your credentials (replace CONFIGURE_ME).

## 6. Re-embed code after edits

If you edit files under `code/`:

```powershell
node scripts/embed-workflow-code.mjs
```

Re-import workflows or paste updated Code node bodies in the UI.

## 7. First test

1. Add 1–2 real companies on `companies` tab (`enabled` = TRUE).
2. **Execute** Workflow A manually (before enabling schedule).
3. Check `jobs` tab for new rows.
4. For an email row: paste `full_jd` + `apply_url`, set `status` = `ready`.
5. **Execute** Workflow B manually.

## VPS next

Set `WEBHOOK_URL`, HTTPS, and the production redirect URI in Google Cloud when moving off localhost.
