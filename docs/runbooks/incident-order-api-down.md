# Runbook: brokerage-api unavailable

**Symptom:** `/health` failing or orders returning 5xx; DataDog shows error
rate spike or missing traces.

## 1. Confirm scope
```bash
kubectl get pods -n brokerage -l app=brokerage-api
kubectl get application brokerage-api -n argocd
```
- All pods down → cluster/platform issue. Some pods down → roll/capacity issue.
- ArgoCD `OutOfSync` / `Degraded` → a bad manifest may have been reconciled.

## 2. Check recent change
GitOps means every change is a commit. Find the last sync:
```bash
kubectl describe application brokerage-api -n argocd | grep -A5 "Revision"
```
If a recent commit caused it, **revert the commit** — ArgoCD will reconcile
back to the good state. Do not hand-edit live resources; they'll be reverted.

## 3. Capacity
```bash
kubectl get hpa -n brokerage
kubectl top pods -n brokerage
```
If maxed at `maxReplicas`, raise it in `gitops/apps/brokerage-api/hpa.yaml`
and commit.

## 4. Observability gap
If pods are healthy but no traces in DataDog, suspect the Collector:
```bash
kubectl logs -n observability deploy/otel-collector --tail=50
kubectl get secret datadog-secret -n observability
```
A missing/expired API key shows as exporter auth errors in the Collector log.

## 5. Escalate
If platform-wide (ArgoCD itself down, nodes NotReady), treat as a cluster
incident and follow cloud-provider/EKS escalation.
