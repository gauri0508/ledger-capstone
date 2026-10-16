import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from prometheus_fastapi_instrumentator import Instrumentator

from app.config import settings
from app.db import ping_db
from app.routers import expenses

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("ledger")

app = FastAPI(title="Ledger API", version=settings.version)

app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.cors_origins),
    allow_methods=["*"],
    allow_headers=["*"],
)

# Exposes /metrics with http_requests_total, http_request_duration_seconds, etc.
Instrumentator(
    should_group_status_codes=False,
    excluded_handlers=["/metrics"],
).instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)

app.include_router(expenses.router)


@app.get("/")
def root():
    return {"name": settings.app_name, "version": settings.version}


@app.get("/health")
def health():
    """Liveness: the process is up and can answer HTTP. Never touches the DB."""
    return {"status": "ok"}


@app.get("/ready")
def ready():
    """Readiness: can this replica actually serve traffic? Needs a working DB."""
    try:
        ping_db()
    except Exception as exc:  # noqa: BLE001 - any DB failure means not ready
        log.warning("readiness check failed: %s", exc)
        return JSONResponse(status_code=503, content={"status": "not ready", "database": "unreachable"})
    return {"status": "ready", "database": "ok"}
