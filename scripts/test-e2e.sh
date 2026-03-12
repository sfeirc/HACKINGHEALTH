#!/usr/bin/env bash
# E2E test: requires Redis, API (port 3000), ML (port 8000) running.
# Start Redis: docker run -d -p 6379:6379 redis:7-alpine
# Start API: cd services/api && npm run dev
# Start ML: cd services/ml && PYTHONPATH=. python3 -m uvicorn app.main:app --port 8000
set -e
BASE64_IMAGE="$(echo -n 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -w0 2>/dev/null || base64)"
BODY="{\"image\":\"$BASE64_IMAGE\"}"
echo "POST /v1/analyze (multipart)..."
# Use a 1x1 pixel PNG as multipart file
echo -n 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==' | base64 -d > /tmp/e2e.png 2>/dev/null || true
RESP=$(curl -s -X POST http://127.0.0.1:3000/v1/analyze -F "image=@/tmp/e2e.png" 2>/dev/null || echo '{}')
JOB_ID=$(echo "$RESP" | node -e "let d=require('fs').readFileSync(0,'utf8'); try { const j=JSON.parse(d); console.log(j.jobId||'') } catch(e){ console.log('') }")
if [ -z "$JOB_ID" ]; then
  echo "FAIL: no jobId in response: $RESP"
  exit 1
fi
echo "JobId: $JOB_ID"
for i in 1 2 3 4 5 6 7 8 9 10; do
  sleep 2
  JOB=$(curl -s "http://127.0.0.1:3000/v1/jobs/$JOB_ID")
  STATUS=$(echo "$JOB" | node -e "let d=require('fs').readFileSync(0,'utf8'); try { const j=JSON.parse(d); console.log(j.status||'') } catch(e){ console.log('') }")
  echo "  Poll $i: status=$STATUS"
  if [ "$STATUS" = "completed" ]; then
    echo "$JOB" | node -e "
      const d=require('fs').readFileSync(0,'utf8');
      const j=JSON.parse(d);
      if(!j.result||!j.result.screening) process.exit(1);
      if(!j.explanation||!j.explanation.summary_title) process.exit(2);
      console.log('E2E OK: result + explanation present');
    "
    exit 0
  fi
  if [ "$STATUS" = "failed" ]; then
    echo "FAIL: job failed: $JOB"
    exit 1
  fi
done
echo "FAIL: job did not complete in time"
exit 1
