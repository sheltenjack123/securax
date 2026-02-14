# Deploy Backend To Render

This repo includes `render.yaml` at the project root.

## 1) Push code to GitHub
- Push this project to your repository.

## 2) Create Render service
- In Render: New + -> Blueprint
- Select your repo
- Render reads `render.yaml` and creates `securax-backend`

## 3) Set required secrets in Render
Set these in Render service Environment:
- `SMTP_EMAIL` = your Gmail ID
- `SMTP_PASSWORD` = 16-char Gmail App Password
- `OWNER_EMAIL` = fallback recipient email

Optional:
- `MAX_EVIDENCE_TO_KEEP` (default `10`)

## 4) Verify
- Open: `https://<your-service>.onrender.com/healthz`
- Open: `https://<your-service>.onrender.com/email_config_status`

## 5) Point app to Render
Build/run app with:

```powershell
flutter run --dart-define=BACKEND_BASE_URL=https://<your-service>.onrender.com
```

For release builds, bake URL with the same `--dart-define`.
