"""Settings come from environment variables so the same image runs everywhere.

Locally and in tests the default is a SQLite file; docker-compose and Kubernetes
set DATABASE_URL to a Postgres URL.
"""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    app_name: str = "ledger"
    version: str = os.getenv("APP_VERSION", "1.1.0")
    database_url: str = os.getenv("DATABASE_URL", "sqlite:///./ledger.db")
    cors_origins: tuple[str, ...] = tuple(
        o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()
    )


settings = Settings()
