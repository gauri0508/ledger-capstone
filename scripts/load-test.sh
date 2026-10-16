#!/usr/bin/env bash
# Generates enough CPU load on the backend for the HPA to scale it out.
# Usage: URL=http://ledger.local/api/expenses/summary PARALLEL=4 DURATION=180 ./scripts/load-test.sh
set -euo pipefail
URL="${URL:-http://ledger.local/api/expenses/summary}"
PARALLEL="${PARALLEL:-4}"
DURATION="${DURATION:-180}"
echo "hammering $URL with $PARALLEL workers for ${DURATION}s"
end=$((SECONDS + DURATION))
for i in $(seq 1 "$PARALLEL"); do
  ( while [ $SECONDS -lt $end ]; do curl -s -o /dev/null "$URL" || true; done ) &
done
wait
echo "load test finished"
