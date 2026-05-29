# Credentials and permissions

This pipeline does **not** need permissions from Cursor or from git. **You** authorize Google and OpenAI in **Google Cloud Console** and **n8n** on your VPS.

## Not “email scraping”

- **Gmail** uses the official **Gmail API** with **OAuth 2.0** (same idea as connecting a mail app).
- Workflow A runs a **search query** only (e.g. `from:jobalerts-noreply@linkedin.com newer_than:2d`) and reads **subject + HTML** to extract job cards and links.
- No IMAP password in code, no bulk mailbox export, no LinkedIn/Glassdoor API keys.

## What you must set up

| Service | What you do | Access |
|---------|-------------|--------|
| **Google (Gmail + Sheets)** | Google Cloud project → enable **Gmail API** + **Google Sheets API** → OAuth consent screen → OAuth client (Web) → connect in n8n | Gmail read (alerts); Sheets read/write (your job sheet). Add `gmail.send` only if the 7 AM reminder is sent via Gmail. |
| **OpenAI** | API key at [platform.openai.com](https://platform.openai.com) → **n8n → Credentials** | Workflow B ranking only (`gpt-4o-mini` or `gpt-4o` per `config` tab). |
| **Tier 1 ATS** | Public job-board URLs in `companies` tab | Usually **no API key** (Greenhouse, Lever, Recruitee, Ashby, SmartRecruiters). |
| **VPS** | Docker + optional HTTPS | n8n stores OAuth tokens encrypted on the server volume. |

## Google Cloud (step by step)

1. Go to [Google Cloud Console](https://console.cloud.google.com/) → create or select a project.
2. **APIs & Services → Library** → enable **Gmail API** and **Google Sheets API**.
3. **OAuth consent screen** → External (or Internal if Workspace) → add app name → **Testing** → add your Gmail under **Test users**.
4. **Credentials → Create credentials → OAuth client ID** → Application type **Web application**.
5. **Authorized redirect URIs** (replace host with yours):

   ```
   https://YOUR_N8N_HOST/rest/oauth2-credential/callback
   ```

   For local Docker testing (if supported): `http://localhost:5678/rest/oauth2-credential/callback`

6. Copy **Client ID** and **Client secret** into n8n when creating **Gmail OAuth2** and **Google Sheets OAuth2** credentials.
7. In n8n: open a workflow → Gmail or Sheets node → **Credential to connect with** → **Create new** → paste client ID/secret → **Sign in with Google** → **Allow**.

## OpenAI (Workflow B only)

1. Create an API key at [platform.openai.com/api-keys](https://platform.openai.com/api-keys).
2. In n8n: **Credentials → Add credential → OpenAI** (or **Header Auth** with `Authorization: Bearer …`).
3. Wire the credential on Workflow B’s OpenAI / HTTP Request node.
4. Set `openai_model` on the Sheet `config` tab (e.g. `gpt-4o-mini`).

Prefer storing the key in **n8n credentials**, not in `.env`. If you use `.env`, never commit `.env`.

## Where secrets live

| Secret | Where | Commit to git? |
|--------|--------|----------------|
| OpenAI API key | n8n credential store | **No** |
| Google OAuth refresh token | n8n after Connect | **No** |
| `SPREADSHEET_ID`, `SHEET_URL`, `REMINDER_EMAIL` | `.env` on VPS | **No** (use `.env.example` as template) |

## OAuth gotchas

1. **Redirect URI** must exactly match your public n8n URL — set `WEBHOOK_URL` in `.env` on the VPS before connecting Google.
2. **Testing mode:** only **Test users** can sign in until you publish the app.
3. **Personal use:** staying in Testing with your own account is fine; no Google verification required.
4. Gmail read scope may show a sensitive-scope warning — expected for your own inbox.

## What you do **not** need

- LinkedIn, Glassdoor, Monster, or Dice developer API keys.
- Apify or browser automation for MVP.
- Cursor or this repo having access to your email.
- Ollama or other local LLMs on the VPS (ranking is **OpenAI only**).

See also: [setup-checklist.md](setup-checklist.md).
