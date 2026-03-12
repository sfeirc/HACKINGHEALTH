#!/usr/bin/env bash
# Start Redis (Docker), ML, and API for local development.
# Run from repo root: ./scripts/run-api-dev.sh
# Ctrl+C stops API and ML.
set -e
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
ML_PID=""

cleanup() {
  if [[ -n "$ML_PID" ]] && kill -0 "$ML_PID" 2>/dev/null; then
    echo "" && echo "Stopping ML service (PID $ML_PID)..."
    kill "$ML_PID" 2>/dev/null || true
  fi
  exit 0
}
trap cleanup SIGINT SIGTERM

echo "=== 1. Redis (port 6379) ==="
if command -v docker &>/dev/null; then
  if docker ps -q -f name=redis-oralscan 2>/dev/null | head -1 | grep -q .; then
    echo "  Redis container already running."
  else
    docker run -d -p 6379:6379 --name redis-oralscan redis:7-alpine 2>/dev/null || docker start redis-oralscan
    echo "  Redis started."
  fi
  sleep 1
else
  echo "  Docker not found. Start Redis manually (e.g. redis-server) on port 6379."
fi

echo ""
echo "=== 2. ML service (port 8000) ==="
if curl -s http://127.0.0.1:8000/health &>/dev/null; then
  echo "  ML already running."
else
  echo "  Starting ML in background..."
  (cd services/ml && PYTHONPATH=. python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000) &
  ML_PID=$!
  sleep 2
  if curl -s http://127.0.0.1:8000/health &>/dev/null; then
    echo "  ML started (PID $ML_PID)."
  else
    echo "  ML may still be starting. If analyses fail, ensure: pip install -r services/ml/requirements.txt"
  fi
fi

echo ""
echo "=== 3. API (port 3000) ==="
lsof -ti :3000 | xargs kill -9 2>/dev/null || true
sleep 1
echo "  Starting API (loads .env from repo root). Ctrl+C to stop."
cd services/api && npm run dev
