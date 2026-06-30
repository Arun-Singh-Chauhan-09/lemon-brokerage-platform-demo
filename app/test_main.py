"""Smoke tests so CI has something real to run."""
from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_get_account_found():
    r = client.get("/accounts/acc_demo_001")
    assert r.status_code == 200
    assert r.json()["id"] == "acc_demo_001"


def test_get_account_missing():
    r = client.get("/accounts/does_not_exist")
    assert r.status_code == 404


def test_create_order_executes():
    r = client.post(
        "/orders",
        json={
            "account_id": "acc_demo_001",
            "isin": "US0378331005",
            "side": "buy",
            "quantity": 1,
        },
    )
    assert r.status_code == 201
    assert r.json()["status"] in {"executed", "rejected"}


def test_create_order_unknown_account():
    r = client.post(
        "/orders",
        json={
            "account_id": "nope",
            "isin": "US0378331005",
            "side": "buy",
            "quantity": 1,
        },
    )
    assert r.status_code == 404
