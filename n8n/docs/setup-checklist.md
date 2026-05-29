# Setup checklist

## 1. VPS and Docker

- [ ] Ubuntu VPS (or local Docker Desktop for testing)
- [ ] Install Docker + Docker Compose
- [ ] Clone repo; `cd n8n`
- [ ] `cp .env.example .env` and edit
- [ ] `docker compose up -d`
- [ ] Open n8n UI (`http://YOUR_HOST:5678` or HTTPS URL)

## 2. Google Sheet

- [ ] Create spreadsheet from `sheets/sheet-template.md` (`jobs`, `companies`, `config` tabs)
- [ ] Copy **Spreadsheet ID** from URL into `.env` → `SPREADSHEET_ID`
- [ ] Set `SHEET_URL` in `.env` and `sheet_url` / `reminder_email` on `config` tab
- [ ] Fill `openai_model`, title reference keys, and `title_similarity_threshold` on `config` tab

## 3. Google Cloud project (Gmail + Sheets OAuth)

- [ ] [Google Cloud Console](https://console.cloud.google.com/) — create or select a project
- [ ] Enable **Gmail API** and **Google Sheets API** (APIs & Services → Library)
- [ ] **OAuth consent screen** → configure app → **Testing** → add your Gmail as **Test user**
- [ ] **Credentials → OAuth client ID → Web application**
- [ ] Add redirect URI: `https://YOUR_N8N_HOST/rest/oauth2-credential/callback`
- [ ] On VPS: set `WEBHOOK_URL=https://YOUR_N8N_HOST/` in `.env` and restart n8n (required before OAuth connect)

Details: [credentials-and-permissions.md](credentials-and-permissions.md)

## 4. n8n credentials

- [ ] **Google Sheets OAuth2** — Client ID + secret from step 3 → Connect → allow spreadsheet access
- [ ] **Gmail OAuth2** — same OAuth client (or separate) → Connect → inbox with job alerts
- [ ] If Workflow A sends reminder via Gmail: ensure send scope is granted (n8n Gmail node “Send”)
- [ ] **OpenAI** — API key in n8n Credentials (Workflow B ranking only; do not commit to git)

## 5. Import workflows

- [ ] **Workflows → Import from File**
- [ ] Import `workflows/workflow-a-daily-collect.json`
- [ ] Import `workflows/workflow-b-bucket-rank.json`
- [ ] Open each workflow; set `SPREADSHEET_ID` on **Set Config** nodes
- [ ] Paste Code node bodies from `code/*.js` if imports show empty Code nodes
- [ ] Attach Google credentials on Gmail/Sheets nodes; OpenAI credential on Workflow B rank node

## 6. Wire Workflow A

- [ ] **Schedule Trigger**: cron `0 7 * * *` (timezone from container `TZ=America/New_York`)
- [ ] **Gmail**: scoped search from workflow notes (LinkedIn, Glassdoor, Monster, Dice senders)
- [ ] **Google Sheets**: document ID + sheet names `jobs`, `companies`, `config`
- [ ] **Reminder Gmail**: `REMINDER_EMAIL` recipient
- [ ] **Activate** Workflow A (toggle Active)

## 7. Wire Workflow B

- [ ] **Manual Trigger** only — do not add Schedule
- [ ] Reads `jobs` where `status` = `ready`
- [ ] OpenAI node uses `openai_model` from `config` tab
- [ ] Updates scores + `bucket_selected`; sets `status` = `ranked`
- [ ] Leave inactive or active (manual runs work either way)

## 8. Test

- [ ] Manual run Workflow A → rows appear on `jobs`
- [ ] Paste `full_jd` + `apply_url` on one email row → `status` = `ready`
- [ ] Manual run Workflow B → scores and `rank_reason` populated

## 9. Production (recommended for OAuth)

- [ ] HTTPS reverse proxy (Caddy/Nginx) in front of n8n
- [ ] `WEBHOOK_URL` and `N8N_PROTOCOL=https` in `.env`
- [ ] Pin n8n image version in `docker-compose.yml`
- [ ] Firewall: expose only 443 (and SSH), not raw 5678 publicly if avoidable
