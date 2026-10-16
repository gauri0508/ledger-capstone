#!/bin/sh
# Run schema migrations first, then start the API. If the migration fails the
# container exits non-zero and Kubernetes/compose restart it instead of serving
# against a wrong schema.
set -e
echo "[entrypoint] running alembic upgrade head against ${DATABASE_URL:-sqlite:///./ledger.db}"
alembic upgrade head
echo "[entrypoint] starting uvicorn"
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --proxy-headers --forwarded-allow-ips="*"
