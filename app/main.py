"""Mock brokerage API.

Three endpoint groups mirror lemon.markets' core domains:
  - account management   (GET /accounts/{id})
  - order management     (POST /orders, GET /orders/{id})
  - availability probes   (GET /health, GET /ready)

This is a demo: state is in-memory, orders are not really executed, and no
real money or securities move. The point is to show a service shaped like a
brokerage API, wired for GitOps deployment and OpenTelemetry observability.
"""
from __future__ import annotations

import os
import random
import time
import uuid
from datetime import datetime, timezone
from enum import Enum
from typing import Dict

from fastapi import FastAPI, HTTPException, status
from pydantic import BaseModel, Field

from otel import setup_telemetry, get_tracer

SERVICE_NAME = os.getenv("OTEL_SERVICE_NAME", "brokerage-api")

app = FastAPI(
    title="Brokerage API (demo)",
    description="Mock Brokerage-as-a-Service API for a GitOps/EKS platform demo.",
    version="0.1.0",
)

# Wire OpenTelemetry. Safe no-op if no exporter endpoint is configured.
setup_telemetry(app, service_name=SERVICE_NAME)
tracer = get_tracer(__name__)

# Mark the process ready a moment after boot so /ready vs /health is meaningful.
_STARTED_AT = time.monotonic()
_READY_AFTER_SECONDS = float(os.getenv("READY_AFTER_SECONDS", "2"))


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------
class OrderSide(str, Enum):
    buy = "buy"
    sell = "sell"


class OrderStatus(str, Enum):
    accepted = "accepted"
    executed = "executed"
    rejected = "rejected"


class OrderRequest(BaseModel):
    account_id: str = Field(..., examples=["acc_demo_001"])
    isin: str = Field(..., min_length=12, max_length=12, examples=["US0378331005"])
    side: OrderSide = Field(..., examples=["buy"])
    quantity: float = Field(..., gt=0, examples=[1.0])


class Order(BaseModel):
    id: str
    account_id: str
    isin: str
    side: OrderSide
    quantity: float
    status: OrderStatus
    created_at: str


class Account(BaseModel):
    id: str
    cash_balance: float
    currency: str = "EUR"


# ---------------------------------------------------------------------------
# In-memory stores (demo only)
# ---------------------------------------------------------------------------
_ACCOUNTS: Dict[str, Account] = {
    "acc_demo_001": Account(id="acc_demo_001", cash_balance=10_000.0),
    "acc_demo_002": Account(id="acc_demo_002", cash_balance=2_500.0),
}
_ORDERS: Dict[str, Order] = {}


# ---------------------------------------------------------------------------
# Availability probes
# ---------------------------------------------------------------------------
@app.get("/health", tags=["availability"])
def health() -> dict:
    """Liveness: is the process up at all?"""
    return {"status": "ok", "service": SERVICE_NAME}


@app.get("/ready", tags=["availability"])
def ready() -> dict:
    """Readiness: is the process ready to take traffic?"""
    uptime = time.monotonic() - _STARTED_AT
    if uptime < _READY_AFTER_SECONDS:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="warming up",
        )
    return {"status": "ready", "uptime_seconds": round(uptime, 1)}


# ---------------------------------------------------------------------------
# Account management
# ---------------------------------------------------------------------------
@app.get("/accounts/{account_id}", response_model=Account, tags=["accounts"])
def get_account(account_id: str) -> Account:
    with tracer.start_as_current_span("get_account") as span:
        span.set_attribute("account.id", account_id)
        account = _ACCOUNTS.get(account_id)
        if account is None:
            span.set_attribute("account.found", False)
            raise HTTPException(status_code=404, detail="account not found")
        span.set_attribute("account.found", True)
        return account


# ---------------------------------------------------------------------------
# Order management
# ---------------------------------------------------------------------------
@app.post("/orders", response_model=Order, status_code=201, tags=["orders"])
def create_order(req: OrderRequest) -> Order:
    """Accept an order, run mock risk checks, and 'execute' it."""
    with tracer.start_as_current_span("create_order") as span:
        span.set_attribute("order.account_id", req.account_id)
        span.set_attribute("order.isin", req.isin)
        span.set_attribute("order.side", req.side.value)
        span.set_attribute("order.quantity", req.quantity)

        account = _ACCOUNTS.get(req.account_id)
        if account is None:
            span.set_attribute("order.rejected_reason", "unknown_account")
            raise HTTPException(status_code=404, detail="account not found")

        # Mock risk check: simulate a downstream latency + occasional rejection.
        with tracer.start_as_current_span("risk_check") as risk_span:
            time.sleep(random.uniform(0.01, 0.08))
            estimated_cost = req.quantity * 100.0  # pretend price
            sufficient_funds = (
                req.side == OrderSide.sell or account.cash_balance >= estimated_cost
            )
            risk_span.set_attribute("risk.estimated_cost", estimated_cost)
            risk_span.set_attribute("risk.sufficient_funds", sufficient_funds)

        order_id = f"ord_{uuid.uuid4().hex[:12]}"
        if not sufficient_funds:
            order = Order(
                id=order_id,
                account_id=req.account_id,
                isin=req.isin,
                side=req.side,
                quantity=req.quantity,
                status=OrderStatus.rejected,
                created_at=datetime.now(timezone.utc).isoformat(),
            )
            _ORDERS[order_id] = order
            span.set_attribute("order.status", order.status.value)
            return order

        # "Execute"
        with tracer.start_as_current_span("execute_order"):
            time.sleep(random.uniform(0.02, 0.10))
            if req.side == OrderSide.buy:
                account.cash_balance -= estimated_cost

        order = Order(
            id=order_id,
            account_id=req.account_id,
            isin=req.isin,
            side=req.side,
            quantity=req.quantity,
            status=OrderStatus.executed,
            created_at=datetime.now(timezone.utc).isoformat(),
        )
        _ORDERS[order_id] = order
        span.set_attribute("order.id", order_id)
        span.set_attribute("order.status", order.status.value)
        return order


@app.get("/orders/{order_id}", response_model=Order, tags=["orders"])
def get_order(order_id: str) -> Order:
    order = _ORDERS.get(order_id)
    if order is None:
        raise HTTPException(status_code=404, detail="order not found")
    return order
