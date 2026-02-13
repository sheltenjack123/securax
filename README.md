# Securax Backend (Render)

This repo is prepared for Render deployment with environment-variable secrets.

## Required Render Environment Variables
- `SMTP_EMAIL`
- `SMTP_PASSWORD`
- `OWNER_EMAIL`

## Optional Environment Variables
- `SMTP_HOST` (default: `smtp.gmail.com`)
- `SMTP_PORT` (default: `465`)
- `MAX_EVIDENCE_TO_KEEP` (default: `10`)

## Health Endpoint
- `GET /healthz`

## Start Command
- `gunicorn server:app --bind 0.0.0.0:$PORT --workers 2 --threads 4 --timeout 120`
