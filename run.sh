#!/bin/bash
set -euo pipefail

dir_root="$(cd "$(dirname "$0")" && pwd)"
cd "$dir_root"

if [ ! -d "$dir_root/backend" ] || [ ! -d "$dir_root/frontend" ]; then
  echo "[error] Run this script from the project root: $dir_root" >&2
  exit 1
fi

mkdir -p "$dir_root/.logs"

# --- Backend ---
cd "$dir_root/backend"
if [ ! -d .venv ]; then
  echo "[setup] Creating Python venv for backend..."
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install --upgrade pip >/dev/null
python -m pip install -r requirements.txt >/dev/null

export PORT=${PORT:-3001}

uvicorn_bin="$(pwd)/.venv/bin/uvicorn"
if [ ! -x "$uvicorn_bin" ]; then
  # fallback to PATH if needed
  uvicorn_bin="uvicorn"
fi

can_check_port=true
command -v lsof >/dev/null 2>&1 || can_check_port=false

should_start=true
if $can_check_port; then
  if lsof -i :"$PORT" >/dev/null 2>&1; then
    should_start=false
  fi
fi

if $should_start; then
  echo "[start] Backend on http://localhost:$PORT"
  nohup "$uvicorn_bin" app:app --host 0.0.0.0 --port "$PORT" --reload > "$dir_root/.logs/backend.log" 2>&1 &
  echo $! > "$dir_root/.logs/backend.pid"
else
  echo "[info] Port $PORT already in use; assuming backend is running."
fi

deactivate >/dev/null 2>&1 || true

# --- Frontend ---
cd "$dir_root/frontend"
port_front=${FRONTEND_PORT:-3000}
if $can_check_port && lsof -i :"$port_front" >/dev/null 2>&1; then
  echo "[info] Frontend port $port_front already in use. Skipping start."
else
  echo "[start] Frontend on http://localhost:$port_front"
  exec python3 -m http.server "$port_front"
fi
