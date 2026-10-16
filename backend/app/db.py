from sqlalchemy import create_engine, text
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import settings

connect_args = {}
if settings.database_url.startswith("sqlite"):
    # TestClient and uvicorn can touch the session from different threads.
    connect_args["check_same_thread"] = False

engine = create_engine(settings.database_url, pool_pre_ping=True, connect_args=connect_args)
SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


def get_db():
    db: Session = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def ping_db() -> bool:
    """Used by /ready: a real round-trip to the database."""
    with engine.connect() as conn:
        conn.execute(text("SELECT 1"))
    return True
