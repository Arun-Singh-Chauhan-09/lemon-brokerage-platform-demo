#!/usr/bin/env bash
# Installs kind and kubectl on Ubuntu/WSL. Docker must be installed separately
# via Docker Desktop with WSL integration enabled (recommended on Windows).
set -euo pipefail

echo "==> Updating apt and installing basics"
sudo apt update
sudo apt install -y python3 python3-venv python3-pip curl ca-certificates make

ARCH="$(dpkg --print-architecture)"   # amd64 / arm64

if ! command -v kubectl >/dev/null 2>&1; then
  echo "==> Installing kubectl"
  curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
else
  echo "==> kubectl already installed"
fi

if ! command -v kind >/dev/null 2>&1; then
  echo "==> Installing kind"
  curl -fsSLo /tmp/kind "https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-${ARCH}"
  sudo install -m 0755 /tmp/kind /usr/local/bin/kind
else
  echo "==> kind already installed"
fi

echo ""
echo "kubectl: $(kubectl version --client -o yaml 2>/dev/null | head -1 || echo present)"
echo "kind:    $(kind version 2>/dev/null || echo present)"
echo ""
if ! command -v docker >/dev/null 2>&1; then
  echo "NOTE: docker not found. Install Docker Desktop on Windows and enable"
  echo "      Settings -> Resources -> WSL Integration for this distro."
fi
echo "Done. Next: make check"
