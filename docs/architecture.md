# Architecture & decisions

## Design principle

For a brokerage API, infrastructure *is* the product. Uptime, security, and
auditability are not operational chores layered on top of a feature — they are
the feature partners are paying for. Every choice in this repo is justified by
that lens.

## Key decisions

**GitOps with ArgoCD (App-of-Apps).** The cluster's desired state lives in
Git. ArgoCD reconciles continuously, so the cluster self-heals toward Git and
every change is an auditable commit — which is exactly the change-control story
a regulated environment needs. Adding a workload is a single file in
`gitops/apps/`.

**Hybrid local/cloud.** The demo defaults to kind so it costs nothing and is
reproducible on any laptop. The same Terraform modules target real EKS; the
gap is documented in `eks-migration.md` rather than hidden. This demonstrates
judgement about cost and reproducibility, not just the ability to follow a
cloud tutorial.

**OTLP with a swappable exporter.** The app emits vendor-neutral OTLP. The
Collector forwards to DataDog (matching the target stack) but can switch to
Grafana/Tempo via config. Observability is therefore portable, not locked in.

**Security as a merge gate, not a report.** tfsec, Checkov, and Trivy run in
CI and *fail the build* on HIGH/CRITICAL findings. OPA policies reject
manifests that run as root, use floating tags, or omit resource limits.

## Stretch-goal backlog

- **Argo Workflows** scheduled batch generating a mock daily tax/reporting
  artifact (demonstrates their second named Argo tool, and the reporting domain).
- **cert-manager + TLS** for in-cluster and ingress encryption.
- **External Secrets Operator** pulling the DataDog key from AWS Secrets
  Manager instead of a Kubernetes secret.
- **Synthetic uptime monitor** + SLO/error-budget dashboard, echoing the
  public status page a brokerage maintains.
- **NetworkPolicies** for east-west traffic restriction.
