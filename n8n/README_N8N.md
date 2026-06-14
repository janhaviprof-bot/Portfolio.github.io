# n8n on Hetzner — beginner setup guide (no domain)

This guide assumes you have **never** used SSH or a cloud server before. Follow the steps **in order**. Do not skip ahead.

**Your goal:** n8n runs on a Hetzner server 24/7 so your job collection runs at **6 AM** even when your laptop is closed. You are the only user. **No domain purchase.**

**Monthly cost:** ~$5 (Hetzner CX23 only).

**Example server IP used below:** `178.104.197.181` — replace with **your** IPv4 from the Hetzner console if different.

---

## Words you will see (quick glossary)

| Term | Plain English |
|------|----------------|
| **SSH** | Secure way to open a remote command line on your server from your laptop |
| **SSH tunnel** | A secure “pipe” so `http://localhost:5678` on your laptop talks to n8n on the server |
| **Docker** | Runs n8n in a container (like a small virtual box) so install is easy |
| **docker compose** | Starts/stops n8n using settings in `docker-compose.yml` |
| **`.env` file** | Text file with your sheet ID, email, timezone — not secret keys for Google (those live inside n8n) |
| **Volume / backup** | Where n8n stores workflows and credentials on disk |
| **root** | Admin user on a new Linux server (normal for Hetzner) |
| **IPv4** | Address like `178.104.197.181` (use this, not the long IPv6 line) |

---

## Before you start — checklist

Make sure all of these are true:

- [ ] Hetzner server is **created** and **running** (green in Hetzner console)
- [ ] You added an **SSH key** when creating the server (or you know the root password from email)
- [ ] **Local n8n already works** on your laptop (`docker compose up -d` → http://localhost:5678)
- [ ] Your **Google Sheet** exists and workflows write to it locally
- [ ] You know your Hetzner **IPv4** (Hetzner → click server → copy IPv4)

You will use **two windows** on your laptop:

1. **PowerShell on Windows** — for `ssh`, `scp`, local Docker
2. **Browser** — for n8n UI at http://localhost:5678 (after SSH tunnel)

---

## Big picture

```
┌─────────────────┐         ┌──────────────────────┐
│  Your laptop    │  SSH    │  Hetzner server      │
│  (can be off    │ tunnel  │  (always on)         │
│   at 6 AM)      │────────▶│  n8n runs schedule   │
└─────────────────┘         └──────────┬───────────┘
                                       │
                                       ▼
                            ┌──────────────────────┐
                            │  Google Sheet        │
                            │  Gmail, OpenAI, ATS  │
                            └──────────────────────┘
```

---

# PART 1 — Connect to your server for the first time

### Step 1.1 — Open PowerShell on Windows

1. Press **Windows key**
2. Type **PowerShell**
3. Click **Windows PowerShell** (blue icon)

You should see a prompt like:

```text
PS C:\Users\janha>
```

### Step 1.2 — Connect with SSH

Type this (use **your** IP if not `178.104.197.181`):

```powershell
ssh root@178.104.197.181
```

Press **Enter**.

**First time only:** you may see:

```text
Are you sure you want to continue connecting (yes/no)?
```

Type **`yes`** and press Enter.

**Success looks like:** prompt changes to something like:

```text
root@ubuntu-4gb-nbg1-1:~#
```

You are now **inside the server**. Commands you type run on Hetzner, not your laptop.

**If it fails:**

| Error | Fix |
|-------|-----|
| `Connection refused` | Server off? Check Hetzner console → server power ON |
| `Permission denied (publickey)` | Wrong SSH key — use the PC where you created the key, or reset root password in Hetzner |
| `ssh is not recognized` | Install OpenSSH Client: Settings → Apps → Optional features → Add **OpenSSH Client** |

---

### Step 1.3 — Update the server

Copy and paste **one line at a time** (or the whole block) into the SSH window:

```bash
apt update && apt upgrade -y
```

This can take **2–5 minutes**. It may ask:

```text
Which services should be restarted?
```

Press **Enter** to accept defaults.

**Success looks like:** command finishes with no red `E:` error lines.

---

### Step 1.4 — Install Docker

Still in SSH:

```bash
curl -fsSL https://get.docker.com | sh
```

Wait until you see a message like **Installation finished**.

Verify Docker works:

```bash
docker --version
```

**Success looks like:** `Docker version 28.x.x` (any recent version is fine).

---

### Step 1.5 — Turn on firewall (SSH only)

```bash
ufw allow OpenSSH
ufw enable
```

When asked `Command may disrupt existing ssh connections. Proceed with operation (y|n)?` type **`y`** and Enter.

**Success looks like:** `Firewall is active and enabled on system startup`

We **do not** open port 5678 to the internet. n8n stays private on the server.

---

### Step 1.6 — Optional: confirm Ubuntu version

```bash
lsb_release -a
```

**Success looks like:** `Release: 24.04`

You can type **`exit`** to leave SSH and return to Windows PowerShell — or open a **second** PowerShell window for the next part.

---

# PART 2 — Copy your n8n folder to the server

Your project files live on your laptop at:

`c:\Work\Job\PortfolioRepo\Portfolio.github.io\n8n`

We copy that entire folder to the server at `/root/n8n`.

### Step 2.1 — Open a **new** PowerShell window on Windows

Do **not** use the SSH window for this. You need a normal Windows prompt:

```text
PS C:\Users\janha>
```

### Step 2.2 — Run `scp` (secure copy)

```powershell
scp -r "c:\Work\Job\PortfolioRepo\Portfolio.github.io\n8n" root@178.104.197.181:/root/
```

Press Enter. Wait **1–3 minutes** (many small files).

**Success looks like:** no error; files copy quietly. At the end you get your `PS C:\...>` prompt back.

**If `.env` is missing on server:** your local `.env` might not have copied if it was created after — see Step 2.3.

---

### Step 2.3 — Check `.env` on the server

SSH back in (if you closed it):

```powershell
ssh root@178.104.197.181
```

List files:

```bash
ls -la /root/n8n
```

**You should see:** `docker-compose.yml`, `docker-compose.server.yml`, `.env`, `workflows`, `code`, etc.

If **`.env` is missing**, copy it from Windows (new PowerShell window):

```powershell
scp "c:\Work\Job\PortfolioRepo\Portfolio.github.io\n8n\.env" root@178.104.197.181:/root/n8n/
```

---

### Step 2.4 — Edit `.env` on the server (if needed)

On the server (SSH):

```bash
nano /root/n8n/.env
```

**nano** is a simple text editor in the terminal.

Your file should match what works locally. Example shape (use **your** real values):

```env
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http
GENERIC_TIMEZONE=America/New_York
TZ=America/New_York

SPREADSHEET_ID=abc123yourSheetId
SHEET_URL=https://docs.google.com/spreadsheets/d/abc123yourSheetId/edit
REMINDER_EMAIL=you@gmail.com
```

**Important:**

- `TZ=America/New_York` — so 6 AM means **Eastern Time**, not Germany time
- Do **not** set `WEBHOOK_URL` to a domain — leave it empty or commented out
- `SPREADSHEET_ID` is the long ID from your Google Sheet URL between `/d/` and `/edit`

**Save in nano:**

1. **Ctrl+O** (letter O) → Enter (writes file)
2. **Ctrl+X** (exit)

**Tip:** To compare with local, open `c:\Work\Job\PortfolioRepo\Portfolio.github.io\n8n\.env` in Notepad on Windows and copy the same values.

---

# PART 3 — Copy your n8n brain from laptop to server

Local n8n stores workflows, Google credentials, and settings in a Docker **volume** named `n8n_n8n_data`. We backup that volume and restore it on Hetzner so you do **not** re-import workflows or reconnect Google from scratch.

### Step 3.1 — Stop local n8n (Windows PowerShell)

```powershell
cd c:\Work\Job\PortfolioRepo\Portfolio.github.io\n8n
docker compose down
```

**Success looks like:** `Container n8n-n8n-1 Removed` or similar.

---

### Step 3.2 — Create backup file

Still in that folder:

```powershell
docker run --rm -v n8n_n8n_data:/data -v ${PWD}:/backup alpine tar czf /backup/n8n-local-backup.tar.gz -C /data .
```

Wait ~30 seconds.

**Success looks like:** no error.

Check the file exists:

```powershell
dir n8n-local-backup.tar.gz
```

You should see a file around **several MB** (size varies).

---

### Step 3.3 — Start local n8n again (so you can still use laptop until cutover)

```powershell
docker compose up -d
```

You can use local n8n until Part 4 is done and you stop it for good.

---

### Step 3.4 — Upload backup to Hetzner

```powershell
scp "c:\Work\Job\PortfolioRepo\Portfolio.github.io\n8n\n8n-local-backup.tar.gz" root@178.104.197.181:/root/n8n/
```

**Success looks like:** progress bar or `100%` for the file.

---

### Step 3.5 — Restore backup on server (SSH)

```powershell
ssh root@178.104.197.181
```

```bash
cd /root/n8n
```

**Step A — create empty Docker volume:**

```bash
docker compose -f docker-compose.yml -f docker-compose.server.yml up -d
```

First run may **download** the n8n image (few minutes). Wait until it finishes.

**Step B — stop n8n so we can overwrite data:**

```bash
docker compose -f docker-compose.yml -f docker-compose.server.yml down
```

**Step C — unpack your backup into the volume:**

```bash
docker run --rm -v n8n_n8n_data:/data -v /root/n8n:/backup alpine tar xzf /backup/n8n-local-backup.tar.gz -C /data
```

**Step D — start n8n for real:**

```bash
docker compose -f docker-compose.yml -f docker-compose.server.yml up -d
```

**Step E — verify running:**

```bash
docker compose -f docker-compose.yml -f docker-compose.server.yml ps
```

**Success looks like:**

```text
NAME        IMAGE              STATUS
n8n-n8n-1   n8nio/n8n:1.76.1   Up X seconds
```

If **STATUS** says `Up`, n8n is running on the server.

View logs if something looks wrong:

```bash
docker compose -f docker-compose.yml -f docker-compose.server.yml logs -f n8n
```

Press **Ctrl+C** to stop watching logs (n8n keeps running).

---

# PART 4 — Open n8n in your browser (SSH tunnel)

n8n on the server listens on **127.0.0.1:5678** only — not on the public internet. An **SSH tunnel** forwards your laptop’s `localhost:5678` to the server.

### Step 4.1 — Start the tunnel (Windows PowerShell)

Open a **new** PowerShell window:

```powershell
ssh -L 5678:127.0.0.1:5678 root@178.104.197.181
```

**Leave this window open.** If you close it, the browser will not connect.

You may land at a server prompt (`root@...#`). That is normal.

---

### Step 4.2 — Open n8n in browser

On Windows, open **Chrome** or **Edge** and go to:

```text
http://localhost:5678
```

**Not** `https`. **Not** your Hetzner IP.

**Success looks like:** n8n login or home screen with **your workflows** (same as local) — e.g. **Final WorkFlow**.

**If the page does not load:**

1. Is the SSH tunnel window still open?
2. Did Part 3 finish with `Up` status?
3. Try `http://127.0.0.1:5678`

---

### Step 4.3 — Test collection manually (before enabling schedule)

1. In n8n, click **Workflows** (left sidebar)
2. Open **Final WorkFlow**
3. Click **Execute workflow** (or **Test workflow** — depends on which trigger you use for collection)
4. Wait for green checkmarks on nodes (can take several minutes for ATS + Gmail)
5. Open your **Google Sheet** in another tab — check for new rows on `jobs` / `unique_jobs`

**If Gmail/Sheets nodes fail:** see [Reconnect Google](#reconnect-gmail-or-google-sheets) below.

---

### Step 4.4 — Turn on the daily schedule

1. Open **Final WorkFlow**
2. Top-right toggle: **Inactive** → click to make **Active** (green)
3. Click the **Schedule Trigger** node and confirm:
   - Hour: **6** (or **7** if you prefer)
   - Timezone: workflow uses server env `America/New_York`

**Success looks like:** workflow shows **Active**; tomorrow morning the sheet should update without your laptop.

---

### Step 4.5 — Stop local n8n (important — avoid running twice)

Once Hetzner works, stop n8n on your laptop. Open PowerShell:

```powershell
cd c:\Work\Job\PortfolioRepo\Portfolio.github.io\n8n
docker compose down
```

**From now on:** only Hetzner runs the 6 AM job. Your laptop can sleep.

---

# How to use it every day

## Normal day (lazy mode — what you wanted)

1. **Do nothing at 6 AM** — server runs automatically
2. Wake up → check **reminder email** or open **Google Sheet**
3. New jobs are already in the sheet

## When you need to paste job descriptions

1. Open Google Sheet (bookmark `SHEET_URL` from your `.env`)
2. Find rows where you need to add text (e.g. `needs_manual_jd` or empty `full_jd`)
3. Paste **full job description** and **apply URL**
4. Set **status** to `ready` (exact column name depends on your sheet template)

## When you want to run ranking

Ranking is **manual** — you run it when the sheet is ready.

1. Open PowerShell:

   ```powershell
   ssh -L 5678:127.0.0.1:5678 root@178.104.197.181
   ```

2. Browser → **http://localhost:5678**
3. Open **Final WorkFlow**
4. Use the **manual / test** trigger for the **ranking** branch (not the schedule trigger)
5. Click **Execute workflow**
6. Check sheet tabs `ranked_*` and your email for results

## When you want to change a workflow or debug

Same as ranking: SSH tunnel → **http://localhost:5678** → edit in n8n UI.

You do **not** need to SSH for the 6 AM run — only when **you** want the UI.

---

## Reconnect Gmail or Google Sheets

If a node says authentication failed:

1. SSH tunnel → **http://localhost:5678**
2. Left sidebar → **Credentials**
3. Click **Gmail** or **Google Sheets** credential
4. Click **Reconnect** / **Sign in with Google**
5. Complete Google login in browser

Your Google Cloud project should already have this redirect URI (from local setup):

```text
http://localhost:5678/rest/oauth2-credential/callback
```

That still works through the SSH tunnel — Google sees `localhost`, not Hetzner.

---

## Command cheat sheet

### Open n8n UI (most common)

```powershell
ssh -L 5678:127.0.0.1:5678 root@178.104.197.181
```

Then browser: **http://localhost:5678**

### On server — restart n8n

```bash
cd /root/n8n
docker compose -f docker-compose.yml -f docker-compose.server.yml up -d --force-recreate
```

### On server — view logs

```bash
cd /root/n8n
docker compose -f docker-compose.yml -f docker-compose.server.yml logs -f n8n
```

(Ctrl+C to exit logs)

### On server — stop n8n completely

```bash
cd /root/n8n
docker compose -f docker-compose.yml -f docker-compose.server.yml down
```

### Switch back to local n8n temporarily

Stop Hetzner n8n first (command above), then on Windows:

```powershell
cd c:\Work\Job\PortfolioRepo\Portfolio.github.io\n8n
docker compose up -d
```

Never run **both** at the same time on the same sheet.

---

## Troubleshooting

### SSH / connection

| Problem | What to do |
|---------|------------|
| `Connection refused` | Hetzner console → server running? |
| `Permission denied` | Use the laptop where your SSH key was created |
| Tunnel open but no UI | Use `http://localhost:5678` not the Hetzner IP |

### Docker on server

| Problem | What to do |
|---------|------------|
| `docker: command not found` | Re-run Part 1 Step 1.4 install script |
| Container not `Up` | Run `logs -f n8n` and read the last red error lines |
| Out of disk | `df -h` — CX23 has 40 GB; usually enough |

### Workflow / sheet

| Problem | What to do |
|---------|------------|
| Nothing at 6 AM | Workflow **Active**? `TZ=America/New_York` in `.env`? Check logs next morning |
| Empty sheet | Wrong `SPREADSHEET_ID` in server `.env`? |
| Duplicate rows | Local n8n still running — run `docker compose down` on laptop |
| Run very slow / timeout | Server has 4 GB RAM; iCIMS is slow by design — timeout is 2 hours |

### Windows backup command fails

If `${PWD}` causes issues, use full path:

```powershell
docker run --rm -v n8n_n8n_data:/data -v "c:/Work/Job/PortfolioRepo/Portfolio.github.io/n8n:/backup" alpine tar czf /backup/n8n-local-backup.tar.gz -C /data .
```

If volume name is wrong, list volumes:

```powershell
docker volume ls
```

Look for something ending in `n8n_data` and replace `n8n_n8n_data` in commands.

---

## Optional later: buy a domain

Not needed for you now. If you ever want `https://n8n.yourdomain.com` without SSH tunnel, see `docker-compose.prod.yml` and `Caddyfile.example`.

---

## Files in this folder

| File | What it is |
|------|------------|
| `docker-compose.yml` | Base n8n (used locally and on server) |
| `docker-compose.server.yml` | Server-only: bind to localhost + 2h timeout |
| `workflows/Final_WorkFlow.json` | Your main workflow (backup restore usually makes re-import unnecessary) |
| `.env` | Your settings (never commit to git) |
| `docs/credentials-and-permissions.md` | Google Cloud OAuth (already done for local) |

---

## Setup order summary

1. SSH → install Docker → firewall  
2. `scp` n8n folder to server  
3. Check `.env` on server  
4. Backup local n8n volume → upload → restore on server  
5. SSH tunnel → http://localhost:5678 → test → **Active** ON  
6. `docker compose down` on laptop  

**Then forget about it until you check your sheet in the morning.**
