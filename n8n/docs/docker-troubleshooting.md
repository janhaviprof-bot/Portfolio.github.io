# Docker troubleshooting (Windows)

## Error: WSL CommandTimedOut

```
listing WSL distros: running wslexec: ...
DockerDesktop/Wsl/CommandTimedOut
wsl.exe -l -v --all: exit status 1
```

Docker opened but **WSL is hung** — often many stuck `wsl.exe` processes. Docker cannot start its `docker-desktop` VMs until `wsl -l -v` works.

### Fix WSL timeout (do in order)

1. **Quit Docker Desktop** (tray → Quit).
2. **Task Manager** → Details → end **all** `wsl.exe` and `wslservice.exe` (there may be 10+).
3. **Admin PowerShell**:
   ```powershell
   wsl --shutdown
   Restart-Service LxssManager -Force -ErrorAction SilentlyContinue
   Restart-Service WSLService -Force -ErrorAction SilentlyContinue
   wsl --update
   ```
4. **Reboot Windows** if step 3 hangs or `wsl -l -v` still times out.
5. After reboot, open **only** Docker Desktop; wait for **Engine running**.
6. Test: `wsl -l -v` then `docker version` (must show **Server**).

### Reset Docker’s WSL distros (if still failing)

Admin PowerShell — **only** the Docker ones (names may vary):

```powershell
wsl --shutdown
wsl --unregister docker-desktop
wsl --unregister docker-desktop-data
```

Then start Docker Desktop again (it recreates those distros). Your Linux Ubuntu installs are **not** removed unless you unregister them by name.

### Nuclear option

Docker Desktop → **Troubleshoot** → **Reset to factory defaults**, then reboot.

---

## Error: 500 Internal Server Error (engine)

```
request returned 500 Internal Server Error for API route ...
dockerDesktopLinuxEngine/v1.53/...
```

The **Docker CLI is installed**, but the **Docker Desktop Linux engine is not healthy**. This affects every image (`n8nio/n8n`, etc.), not only n8n. Usually fixed by the WSL steps above first.

## Fix (try in order)

### 1. Restart Docker Desktop

1. Quit Docker Desktop fully (tray icon → Quit).
2. Start **Docker Desktop** again.
3. Wait until the status says **Engine running** (can take 1–2 minutes).
4. Test:

   ```powershell
   docker version
   ```

   You must see both **Client** and **Server** sections without errors.

### 2. Restart WSL (common on Windows)

In PowerShell **as Administrator**:

```powershell
wsl --shutdown
```

Then start Docker Desktop again and retry `docker version`.

### 3. Docker Desktop repair

Docker Desktop → **Settings** → **Troubleshoot** (or bug icon):

- **Restart Docker Desktop**
- If still broken: **Clean / Purge data** (removes containers/images; n8n volume would be recreated)
- Last resort: **Reset to factory defaults**

### 4. WSL2 backend

Settings → **General** → ensure **Use the WSL 2 based engine** is enabled.

Update WSL:

```powershell
wsl --update
```

### 5. Pull and start n8n

```powershell
cd c:\Work\Job\PortfolioRepo\Portfolio.github.io\n8n
docker pull n8nio/n8n:1.76.1
docker compose up -d
```

Open http://localhost:5678

## Run n8n without Docker (temporary)

If Docker stays broken, you can run n8n with Node 20+:

```powershell
cd c:\Work\Job\PortfolioRepo\Portfolio.github.io\n8n
$env:TZ="America/New_York"
$env:GENERIC_TIMEZONE="America/New_York"
$env:N8N_BLOCK_ENV_ACCESS_IN_NODE="false"
# Load .env vars manually or use dotenv
npx n8n@1.76.1
```

Import workflows the same way in the UI. Data is stored under `%USERPROFILE%\.n8n` instead of a Docker volume.

## Still failing?

- Reboot Windows after `wsl --shutdown`.
- Update Docker Desktop to the latest version.
- Check virtualization is enabled in BIOS (Intel VT-x / AMD-V).
