# SLO & error budget (brokerage-api)

## Proposed SLOs

| SLI | Target |
|---|---|
| Availability (`/health` 200s) | 99.9% monthly |
| Order API success (non-5xx on `POST /orders`) | 99.5% monthly |
| Order latency (p95 `create_order` span) | < 300 ms |

## Error budget

99.9% monthly availability ≈ **43 minutes** of allowed downtime per 30 days.

- Budget healthy → ship freely.
- Budget < 25% remaining → freeze risky changes, prioritise reliability work.
- Budget exhausted → change freeze except fixes until the window resets.

## Where the signals come from

The `create_order` → `risk_check` → `execute_order` spans give per-stage
latency in DataDog, so you can tell whether slowness is the risk check or
execution. Request-level spans (auto-instrumented) give availability and
error rate. Wire DataDog monitors to these and alert on burn rate, not just
threshold breaches.
