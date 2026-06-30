# Multi-stage, non-root, pinned base — security-conscious by default.
FROM python:3.12-slim AS base

# Don't write .pyc, unbuffered logs for container-friendly output.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py otel.py ./

# Run as an unprivileged user (OPA/Checkov-friendly).
RUN useradd --create-home --uid 10001 appuser
USER 10001

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8080/health').status==200 else 1)"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
