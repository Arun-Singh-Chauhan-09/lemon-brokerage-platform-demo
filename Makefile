# One-command local demo. The Makefile manages its own Python venv, so users
# never deal with python-vs-python3 or "module not found". It auto-detects the
# Python binary and creates app/.venv on first use.
CLUSTER := lemon-demo
IMAGE   := brokerage-api:local

# Pick whichever Python exists (python3 on Linux/WSL/macOS, python on some setups).
PYTHON := $(shell command -v python3 2>/dev/null || command -v python 2>/dev/null)
VENV   := app/.venv
VPY    := $(VENV)/bin/python

.PHONY: help check venv test run build load up apps datadog-secret demo destroy clean

help:
	@echo "Setup & app:"
	@echo "  make check    - verify required tools are installed"
	@echo "  make test     - set up venv (auto) and run unit tests"
	@echo "  make run      - run the API locally on http://localhost:8080"
	@echo ""
	@echo "Cluster demo (needs docker, kind, kubectl):"
	@echo "  make demo     - full path: cluster -> ArgoCD -> build -> deploy"
	@echo "  make destroy  - delete the kind cluster"
	@echo ""
	@echo "  make clean    - remove the local venv"

# --- verify prerequisites, print friendly hints for whatever is missing ------
check:
	@echo "Checking prerequisites..."
	@if [ -z "$(PYTHON)" ]; then \
		echo "  [X] python3   -> sudo apt install python3 python3-venv python3-pip -y"; \
	else echo "  [ok] python   -> $(PYTHON)"; fi
	@command -v docker  >/dev/null 2>&1 && echo "  [ok] docker" || echo "  [X] docker    -> install Docker Desktop (enable WSL integration)"
	@command -v kind    >/dev/null 2>&1 && echo "  [ok] kind"   || echo "  [X] kind      -> see scripts/install-tools.sh"
	@command -v kubectl >/dev/null 2>&1 && echo "  [ok] kubectl" || echo "  [X] kubectl   -> see scripts/install-tools.sh"
	@echo "Done. Anything marked [X] needs installing before 'make demo'."

# --- create the venv only if it doesn't already exist ------------------------
$(VPY):
	@test -n "$(PYTHON)" || { echo "No python found. Run: sudo apt install python3 python3-venv python3-pip -y"; exit 1; }
	$(PYTHON) -m venv $(VENV)
	$(VENV)/bin/pip install --upgrade pip
	$(VENV)/bin/pip install -r app/requirements-dev.txt

venv: $(VPY)
	@echo "venv ready at $(VENV)"

test: $(VPY)
	$(VPY) -m pytest -q app

run: $(VPY)
	$(VPY) -m uvicorn main:app --app-dir app --host 0.0.0.0 --port 8080 --reload

# --- cluster demo ------------------------------------------------------------
up:
	kind create cluster --config infra/local/kind-config.yaml
	kubectl create namespace argocd || true
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "Waiting for ArgoCD server..."
	kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

build:
	docker build -t $(IMAGE) ./app

load:
	kind load docker-image $(IMAGE) --name $(CLUSTER)

datadog-secret:
	@test -n "$(DD_API_KEY)" || (echo "Set DD_API_KEY=... first"; exit 1)
	kubectl create namespace observability || true
	kubectl create secret generic datadog-secret \
		--namespace observability \
		--from-literal=api-key=$(DD_API_KEY) \
		--dry-run=client -o yaml | kubectl apply -f -

apps:
	kubectl apply -f gitops/bootstrap/app-of-apps.yaml
	kubectl apply -f infra/local/nodeport.yaml
	@echo "ArgoCD is now reconciling. Watch with: kubectl get applications -n argocd -w"

demo: up build load apps
	@echo ""
	@echo "Done. ArgoCD admin password:"
	@echo "  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
	@echo "UI:  kubectl port-forward svc/argocd-server -n argocd 8081:443  (then https://localhost:8081)"
	@echo "API: curl localhost:8080/health"

destroy:
	kind delete cluster --name $(CLUSTER)

clean:
	rm -rf $(VENV)
