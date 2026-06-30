"""OpenTelemetry wiring for the brokerage API.

Design goal: the app exports OTLP. Where that OTLP goes is a deployment
concern, not an app concern. Locally and in the cluster we point the app at
an OpenTelemetry Collector, and the Collector forwards to DataDog. Swapping
DataDog for Grafana/Tempo is a Collector config change, not a code change.
This keeps the demo working after a time-limited DataDog trial expires.

If OTEL_EXPORTER_OTLP_ENDPOINT is unset, telemetry setup becomes a no-op so
the app still runs (e.g. in unit tests) without a Collector present.
"""
from __future__ import annotations

import os

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


def setup_telemetry(app, service_name: str) -> None:
    endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")

    resource = Resource.create(
        {
            "service.name": service_name,
            "service.version": os.getenv("SERVICE_VERSION", "0.1.0"),
            "deployment.environment": os.getenv("DEPLOY_ENV", "local"),
        }
    )
    provider = TracerProvider(resource=resource)

    if endpoint:
        # Imported lazily so the package is only required when actually exporting.
        from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import (
            OTLPSpanExporter,
        )

        provider.add_span_processor(
            BatchSpanProcessor(OTLPSpanExporter(endpoint=endpoint, insecure=True))
        )

    trace.set_tracer_provider(provider)

    # Auto-instrument FastAPI so every request becomes a span automatically;
    # the manual spans in main.py add business context (order id, risk result).
    try:
        from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

        FastAPIInstrumentor.instrument_app(app)
    except Exception:  # pragma: no cover - instrumentation is best-effort
        pass


def get_tracer(name: str):
    return trace.get_tracer(name)
