"""Every test session gets its own throw-away SQLite file.

DATABASE_URL has to be set *before* app.config is imported, which is why this
lives at module level rather than in a fixture.
"""

import os
import sys
import tempfile
from pathlib import Path

_tmpdir = tempfile.mkdtemp(prefix="ledger-test-")
os.environ["DATABASE_URL"] = f"sqlite:///{Path(_tmpdir) / 'test.db'}"

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

from app.db import Base, engine  # noqa: E402
from app.main import app  # noqa: E402


@pytest.fixture(autouse=True)
def clean_tables():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    yield
    Base.metadata.drop_all(engine)


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c
