# Compliance-as-code

A regulated broker has to *prove* controls are in place, continuously. This
repo encodes a baseline set of controls so they are enforced automatically and
visibly, rather than checked manually after the fact.

## Controls and where they live

| Control | Enforcement |
|---|---|
| Data encrypted at rest | `storage_encrypted = true` on RDS; Checkov fails if removed |
| Least-privilege IAM | IRSA module scopes permissions to a SecretsManager path prefix, not `*` |
| No root containers | OPA `deny.rego` rule + Pod `securityContext.runAsNonRoot` |
| Pinned images (auditability) | OPA rule rejecting `:latest` |
| Resource limits (stability/cost) | OPA rule requiring `resources.limits` |
| Vulnerability management | Trivy scans images, fails on HIGH/CRITICAL |
| IaC misconfiguration | tfsec + Checkov gate every PR |
| Change control / audit trail | GitOps: every change is a reviewed, traceable Git commit |
| Availability | multi-replica + PDB + multi-AZ RDS |

## How to run the checks locally

```bash
# OPA / Conftest policies against the manifests
conftest test gitops/ -p policies/opa

# Checkov across Terraform + Kubernetes
checkov --config-file policies/checkov/.checkov.yaml
```

## Intentional demo gaps

Some controls (image signing, full network policy with a CNI that enforces it,
KMS customer-managed keys) are noted but not implemented to keep the demo
laptop-runnable. They're listed here rather than silently skipped — knowing
what's *not* covered is part of a credible compliance posture.
