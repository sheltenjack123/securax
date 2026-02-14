# Securax Backend Autostart (Windows)

Use these commands once:

```powershell
cd D:\Downloads\securax\backend
powershell -ExecutionPolicy Bypass -File .\install_autostart.ps1
```

What it does:
- Creates a scheduled task `SecuraxBackendAutostart`
- Runs `start_backend.ps1` at Windows logon
- Starts backend immediately now
- If scheduled task is blocked by permissions, it falls back to Startup folder launcher

Check status:

```powershell
Invoke-WebRequest http://127.0.0.1:5000/email_config_status
```

Manual controls:

```powershell
powershell -ExecutionPolicy Bypass -File .\start_backend.ps1
powershell -ExecutionPolicy Bypass -File .\stop_backend.ps1
powershell -ExecutionPolicy Bypass -File .\uninstall_autostart.ps1
```
