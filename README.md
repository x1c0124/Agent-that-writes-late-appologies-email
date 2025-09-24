# Late Email Agent (Fullstack)

Generate and send professional emails explaining lateness for class, project submissions, or conferences.

## Features
- Backend API (FastAPI) using OpenAI Chat Completions for high-quality drafts (fallback template without key)
- MailerSend integration to send the generated email
- Frontend single-page app to collect inputs and preview/copy/send

## Prerequisites
- Python 3.10+
- OpenAI API key (optional but recommended)
- MailerSend API key (optional; needed to send emails)

## Setup

### 1) Backend
```bash
cd "backend"
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export PORT=3001
# Optional keys
export OPENAI_API_KEY=sk-... # your key
export OPENAI_MODEL=gpt-4o-mini
export CORS_ORIGIN="http://localhost:3000,http://127.0.0.1:3000"
# Optional to enable sending
export MAILERSEND_API_KEY=ms_...
python app.py
```
Server will listen on http://localhost:3001

### 2) Frontend
Open the app or run a static server:
```bash
cd "frontend"
python3 -m http.server 3000
```
Open http://localhost:3000 in your browser.

If your backend runs elsewhere:
```js
localStorage.setItem('late_backend_url', 'http://localhost:3001')
```

## API
- GET /health → { ok: true }
- POST /generate → returns { subject, body }
- POST /send → { fromEmail, fromName, toEmail, subject, bodyText, bodyHtml? }

## Notes
- Without OPENAI_API_KEY, /generate returns a deterministic template.
- Use a MailerSend verified domain for fromEmail.

## Deploy (Render)
1) Commit and push this repo to GitHub.
2) On Render, create a new Web Service from the repo with `render.yaml` autodetected.
3) Set environment variables for the backend service:
   - `OPENAI_API_KEY` (optional)
   - `OPENAI_MODEL` (default `gpt-4o-mini`)
   - `MAILERSEND_API_KEY` (optional)
   - `CORS_ORIGIN` to the frontend URL (Render will provide it after first deploy)
4) The static site will serve the frontend from `/frontend`. Update `CORS_ORIGIN` to the exact frontend domain.
5) In the browser console on the deployed frontend, set backend URL if needed:
```js
localStorage.setItem('late_backend_url', 'https://<your-backend-onrender>.onrender.com')
```

## Deploy/run with Docker
```bash
# optional env (recommended for real email/LLM)
export OPENAI_API_KEY=sk-...
export MAILERSEND_API_KEY=ms-...

# build and run both services
docker compose up --build -d

# open
# frontend: http://localhost:3000
# backend:  http://localhost:3001/health
```
