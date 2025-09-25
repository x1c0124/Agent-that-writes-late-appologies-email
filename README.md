# Agent that writes late apologies email

Generate and send professional emails explaining lateness for class, project submissions, or conferences.

## Features
- Backend API (FastAPI) using OpenAI Chat Completions for high-quality drafts (fallback template without key)
- MailerSend integration to send the generated email
- Frontend single-page app to collect inputs and preview/copy/send
- Management script for easy start/stop

## Quick Start

### Using the management script (recommended)
```bash
# Start both services
./manage.sh start

# Check status
./manage.sh status

# Stop services
./manage.sh stop

# View logs
./manage.sh logs

# Test API
./manage.sh test
```

### Manual setup

#### Backend
```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export OPENAI_API_KEY=sk-... # optional
export MAILERSEND_API_KEY=ms-... # optional
python app.py
```

#### Frontend
```bash
cd frontend
python3 -m http.server 3000
```

## URLs
- Frontend: http://localhost:3000
- Backend: http://localhost:3001
- Health check: http://localhost:3001/health

## Environment Variables
See `backend/.env.example` for configuration options.

## API Endpoints
- `GET /health` → `{ ok: true }`
- `POST /generate` → `{ subject, body, model, usedLLM }`
- `POST /send` → `{ fromEmail, fromName, toEmail, subject, bodyText, bodyHtml? }`

## Deploy
- **Render**: Use `render.yaml` for automatic deployment
- **Docker**: Use `docker-compose.yml` for containerized deployment

## Notes
- Without `OPENAI_API_KEY`, `/generate` returns a deterministic template
- Use a MailerSend verified domain for `fromEmail`
