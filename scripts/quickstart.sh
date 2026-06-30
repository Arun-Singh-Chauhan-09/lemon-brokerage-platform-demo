#!/usr/bin/env bash
# Get the API running locally with one command. No cluster needed.
# Usage: ./scripts/quickstart.sh
set -euo pipefail

cd "$(dirname "$0")/.."

PYTHON="$(command -v python3 || command -v python || true)"
if [ -z "$PYTHON" ]; then
  echo "Python not found. Install it first:"
  echo "  sudo apt install python3 python3-venv python3-pip -y"
  exit 1
fi

echo "==> Using $PYTHON"
if [ ! -d app/.venv ]; then
  echo "==> Creating virtualenv (app/.venv)"
  "$PYTHON" -m venv app/.venv
fi

echo "==> Installing dependencies"
app/.venv/bin/pip install --upgrade pip >/dev/null
app/.venv/bin/pip install -r app/requirements-dev.txt

echo "==> Running tests"
app/.venv/bin/python -m pytest -q app

echo ""
echo "All good. Start the API with:"
echo "  make run"
echo "Then in another terminal:"
echo "  curl localhost:8080/health"
