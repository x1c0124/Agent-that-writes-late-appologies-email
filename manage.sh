#!/bin/bash
# Late Email Agent Management Script

set -euo pipefail

ABS_ROOT="/Users/charlotte/Desktop/agent that writes late appologies email"
LOG_DIR="$ABS_ROOT/.logs"
BACKEND_DIR="$ABS_ROOT/backend"
FRONTEND_DIR="$ABS_ROOT/frontend"

mkdir -p "$LOG_DIR"

case "${1:-start}" in
    start)
        echo "🚀 Starting Late Email Agent..."

        # Backend
        echo "📦 Setting up backend..."
        cd "$BACKEND_DIR"
        if [ ! -d .venv ]; then
            echo "Creating Python venv..."
            python3 -m venv .venv
        fi
        source .venv/bin/activate
        python -m pip install --upgrade pip >/dev/null
        pip install -r requirements.txt >/dev/null

        # Stop existing backend
        if [ -f "$LOG_DIR/backend.pid" ]; then
            PID=$(cat "$LOG_DIR/backend.pid" 2>/dev/null || true)
            if [ -n "$PID" ] && ps -p "$PID" >/dev/null 2>&1; then
                echo "Stopping existing backend..."
                kill "$PID" || true
                sleep 1
            fi
        fi
        lsof -ti :3001 | xargs -r kill -9 || true

        # Start backend
        echo "🔧 Starting backend on http://localhost:3001"
        nohup .venv/bin/uvicorn app:app --host 0.0.0.0 --port 3001 --reload > "$LOG_DIR/backend.log" 2>&1 &
        echo $! > "$LOG_DIR/backend.pid"

        # Frontend
        if ! lsof -i :3000 -sTCP:LISTEN -Pn >/dev/null 2>&1; then
            echo "🌐 Starting frontend on http://localhost:3000"
            (cd "$FRONTEND_DIR" && nohup python3 -m http.server 3000 > "$LOG_DIR/frontend.log" 2>&1 & echo $! > "$LOG_DIR/frontend.pid")
        else
            echo "🌐 Frontend already running on http://localhost:3000"
        fi

        sleep 2
        echo "✅ Services started!"
        echo "   Backend:  http://localhost:3001"
        echo "   Frontend: http://localhost:3000"
        echo "   Health:   http://localhost:3001/health"
        ;;

    stop)
        echo "🛑 Stopping services..."

        # Stop backend
        if [ -f "$LOG_DIR/backend.pid" ]; then
            PID=$(cat "$LOG_DIR/backend.pid" 2>/dev/null || true)
            if [ -n "$PID" ] && ps -p "$PID" >/dev/null 2>&1; then
                echo "Stopping backend (PID: $PID)..."
                kill "$PID" || true
            fi
            rm -f "$LOG_DIR/backend.pid"
        fi

        # Stop frontend
        if [ -f "$LOG_DIR/frontend.pid" ]; then
            PID=$(cat "$LOG_DIR/frontend.pid" 2>/dev/null || true)
            if [ -n "$PID" ] && ps -p "$PID" >/dev/null 2>&1; then
                echo "Stopping frontend (PID: $PID)..."
                kill "$PID" || true
            fi
            rm -f "$LOG_DIR/frontend.pid"
        fi

        # Force kill any remaining processes
        lsof -ti :3001 | xargs -r kill -9 || true
        lsof -ti :3000 | xargs -r kill -9 || true

        echo "✅ Services stopped!"
        ;;

    status)
        echo "📊 Service Status:"
        echo "Backend:"
        if lsof -i :3001 -sTCP:LISTEN -Pn >/dev/null 2>&1; then
            echo "  ✅ Running on http://localhost:3001"
            if [ -f "$LOG_DIR/backend.pid" ]; then
                PID=$(cat "$LOG_DIR/backend.pid" 2>/dev/null || true)
                echo "  PID: $PID"
            fi
        else
            echo "  ❌ Not running"
        fi

        echo "Frontend:"
        if lsof -i :3000 -sTCP:LISTEN -Pn >/dev/null 2>&1; then
            echo "  ✅ Running on http://localhost:3000"
            if [ -f "$LOG_DIR/frontend.pid" ]; then
                PID=$(cat "$LOG_DIR/frontend.pid" 2>/dev/null || true)
                echo "  PID: $PID"
            fi
        else
            echo "  ❌ Not running"
        fi
        ;;

    logs)
        echo "📋 Recent logs:"
        echo "--- Backend Log ---"
        tail -n 20 "$LOG_DIR/backend.log" 2>/dev/null || echo "No backend log found"
        echo ""
        echo "--- Frontend Log ---"
        tail -n 10 "$LOG_DIR/frontend.log" 2>/dev/null || echo "No frontend log found"
        ;;

    test)
        echo "🧪 Testing API..."
        echo "Health check:"
        curl -sS http://localhost:3001/health | python3 -m json.tool || echo "❌ Backend not responding"
        echo ""
        echo "Email generation test:"
        curl -sS -X POST http://localhost:3001/generate \
            -H "Content-Type: application/json" \
            -d '{"personName":"Test User","recipientName":"Professor","context":"class","reason":"test"}' | \
            python3 -m json.tool || echo "❌ Generation failed"
        ;;

    *)
        echo "Usage: $0 {start|stop|status|logs|test}"
        echo ""
        echo "Commands:"
        echo "  start  - Start backend and frontend services"
        echo "  stop   - Stop all services"
        echo "  status - Show service status"
        echo "  logs   - Show recent logs"
        echo "  test   - Test API endpoints"
        exit 1
        ;;
esac
