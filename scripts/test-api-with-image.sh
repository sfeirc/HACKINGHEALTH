#!/usr/bin/env bash
# Test API/ML with a real image (e.g. dental photo).
# Usage: ./scripts/test-api-with-image.sh [path/to/image.jpg]
# Requires: ML service on port 8000 (for ML-only test).
# For full API test: Redis + API (3000) + ML (8000). Set API_URL to run full test.
set -e

IMAGE_PATH="${1:-$(dirname "$0")/../Les-causes-dapparition-des-caries-dentaires-1024x576.jpg}"
if [ ! -f "$IMAGE_PATH" ]; then
  echo "Image not found: $IMAGE_PATH"
  exit 1
fi

ML_URL="${ML_URL:-http://127.0.0.1:8000}"
API_URL="${API_URL:-}"

echo "=== 1. ML /infer (direct) ==="
echo "Image: $IMAGE_PATH"
B64=$(base64 -w0 "$IMAGE_PATH" 2>/dev/null || base64 < "$IMAGE_PATH")
echo "Payload size: ${#B64} chars (base64)"
RESP=$(curl -s -X POST "$ML_URL/infer" \
  -H "Content-Type: application/json" \
  -d "{\"image\":\"$B64\"}")
echo "Response:"
echo "$RESP" | python3 -m json.tool 2>/dev/null || echo "$RESP"

# Basic checks on ML response
if echo "$RESP" | grep -q '"image_quality"'; then
  echo "  [OK] ML returned image_quality"
else
  echo "  [FAIL] ML response missing image_quality"
  exit 1
fi
if echo "$RESP" | grep -q '"screening"'; then
  echo "  [OK] ML returned screening"
else
  echo "  [FAIL] ML response missing screening"
  exit 1
fi
USABLE=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('image_quality',{}).get('usable',None))" 2>/dev/null || echo "")
echo "  image_quality.usable = $USABLE"
echo ""

if [ -z "$API_URL" ]; then
  echo "=== Full API test skipped (set API_URL=http://127.0.0.1:3000 to run) ==="
  exit 0
fi

echo "=== 2. API /v1/analyze (upload + job) ==="
JOB_RESP=$(curl -s -X POST "$API_URL/v1/analyze" -F "image=@$IMAGE_PATH")
echo "$JOB_RESP"
JOB_ID=$(echo "$JOB_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('jobId',''))" 2>/dev/null || echo "")
if [ -z "$JOB_ID" ]; then
  echo "[FAIL] No jobId in response"
  exit 1
fi
echo "JobId: $JOB_ID"
echo ""

echo "=== 3. Poll /v1/jobs/$JOB_ID ==="
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  sleep 2
  JOB=$(curl -s "$API_URL/v1/jobs/$JOB_ID")
  STATUS=$(echo "$JOB" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null || echo "")
  echo "  Poll $i: status=$STATUS"
  if [ "$STATUS" = "completed" ]; then
    echo ""
    echo "Full result:"
    echo "$JOB" | python3 -m json.tool 2>/dev/null || echo "$JOB"
    if echo "$JOB" | grep -q '"result"'; then
      echo "  [OK] API returned result"
    else
      echo "  [FAIL] API result missing"
      exit 1
    fi
    echo "  [OK] E2E with image passed"
    exit 0
  fi
  if [ "$STATUS" = "failed" ]; then
    ERR=$(echo "$JOB" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('error',''))" 2>/dev/null || echo "")
    echo "  [FAIL] Job failed: $ERR"
    echo "$JOB" | python3 -m json.tool 2>/dev/null || echo "$JOB"
    exit 1
  fi
done
echo "[FAIL] Job did not complete in time"
exit 1
