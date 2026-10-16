from datetime import date
from decimal import Decimal

SAMPLE = {"amount": "249.50", "category": "food", "note": "lunch", "spent_on": "2026-10-03"}


def test_root_reports_name_and_version(client):
    r = client.get("/")
    assert r.status_code == 200
    assert r.json()["name"] == "ledger"
    assert "version" in r.json()


def test_health_is_liveness_only(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_ready_checks_database(client):
    r = client.get("/ready")
    assert r.status_code == 200
    assert r.json()["database"] == "ok"


def test_metrics_exposes_prometheus_counters(client):
    client.get("/health")  # make sure at least one request has been counted
    r = client.get("/metrics")
    assert r.status_code == 200
    body = r.text
    assert "http_requests_total" in body
    assert "http_request_duration_seconds" in body


def test_create_and_get_expense(client):
    r = client.post("/api/expenses", json=SAMPLE)
    assert r.status_code == 201
    created = r.json()
    assert created["id"] > 0
    assert created["amount"] == "249.50"
    assert created["category"] == "food"
    assert created["spent_on"] == "2026-10-03"

    r = client.get(f"/api/expenses/{created['id']}")
    assert r.status_code == 200
    assert r.json() == created


def test_list_and_filter_by_category(client):
    client.post("/api/expenses", json=SAMPLE)
    client.post("/api/expenses", json={**SAMPLE, "category": "transport", "amount": "60"})
    client.post("/api/expenses", json={**SAMPLE, "amount": "12.00"})

    assert len(client.get("/api/expenses").json()) == 3
    food = client.get("/api/expenses", params={"category": "food"}).json()
    assert len(food) == 2
    assert all(e["category"] == "food" for e in food)


def test_update_expense(client):
    expense_id = client.post("/api/expenses", json=SAMPLE).json()["id"]
    r = client.put(f"/api/expenses/{expense_id}", json={**SAMPLE, "amount": "300", "note": "dinner"})
    assert r.status_code == 200
    assert r.json()["amount"] == "300.00"
    assert r.json()["note"] == "dinner"


def test_delete_expense_then_404(client):
    expense_id = client.post("/api/expenses", json=SAMPLE).json()["id"]
    assert client.delete(f"/api/expenses/{expense_id}").status_code == 204
    assert client.get(f"/api/expenses/{expense_id}").status_code == 404
    assert client.delete(f"/api/expenses/{expense_id}").status_code == 404


def test_unknown_expense_is_404(client):
    r = client.get("/api/expenses/9999")
    assert r.status_code == 404
    assert "not found" in r.json()["detail"]


def test_negative_amount_is_rejected(client):
    r = client.post("/api/expenses", json={**SAMPLE, "amount": "-5"})
    assert r.status_code == 422
    r = client.post("/api/expenses", json={**SAMPLE, "amount": "0"})
    assert r.status_code == 422


def test_missing_category_is_rejected(client):
    r = client.post("/api/expenses", json={"amount": "10", "spent_on": "2026-10-01"})
    assert r.status_code == 422


def test_summary_totals_and_top_category(client):
    today = date.today().isoformat()
    client.post("/api/expenses", json={"amount": "100", "category": "food", "spent_on": today})
    client.post("/api/expenses", json={"amount": "50", "category": "food", "spent_on": today})
    client.post("/api/expenses", json={"amount": "400", "category": "rent", "spent_on": "2020-01-15"})

    r = client.get("/api/expenses/summary")
    assert r.status_code == 200
    s = r.json()
    assert s["count"] == 3
    assert s["total"] == "550.00"
    assert s["month_total"] == "150.00"  # the 2020 rent is outside this month
    assert s["top_category"] == "rent"
    assert {c["category"]: c["total"] for c in s["by_category"]} == {"rent": "400.00", "food": "150.00"}


def test_summary_on_empty_db(client):
    s = client.get("/api/expenses/summary").json()
    assert s["count"] == 0
    assert Decimal(s["total"]) == 0
    assert Decimal(s["month_total"]) == 0
    assert s["top_category"] is None
    assert s["by_category"] == []
