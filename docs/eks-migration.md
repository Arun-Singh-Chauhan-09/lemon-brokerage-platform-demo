# From local kind to real EKS

The demo runs on kind so it's free and reproducible. This is the documented
path to running the identical platform on AWS. Nothing in `gitops/` changes —
GitOps means the cluster pulls the same manifests regardless of where it runs.
Only the cluster substrate and image source differ.

## What changes

| Concern | Local (kind) | AWS (EKS) |
|---|---|---|
| Cluster | `kind create cluster` | `terraform apply` (eks module) |
| Image | built + `kind load` | pushed to ECR, OIDC auth from CI |
| API exposure | NodePort on localhost:8080 | AWS Load Balancer Controller + Ingress |
| DataDog secret | `kubectl create secret` | External Secrets Operator ← Secrets Manager |
| Persistence | in-memory | encrypted multi-AZ RDS (rds module) |
| Pod IAM | none | IRSA-scoped roles (irsa module) |

## Steps

1. **Network + cluster**
   ```bash
   cd infra
   terraform init
   terraform apply -var-file=envs/aws.tfvars   # vpc -> eks -> rds
   aws eks update-kubeconfig --name lemon-brokerage-demo --region eu-central-1
   ```

2. **Install ArgoCD**, then apply `gitops/bootstrap/app-of-apps.yaml`. ArgoCD
   reconciles everything else from Git, exactly as it did locally.

3. **Images via OIDC.** In CI, replace the "image built" step with an ECR push
   using GitHub Actions OIDC (no long-lived AWS keys). Update the deployment
   image to the ECR URI.

4. **Secrets.** Deploy External Secrets Operator; it syncs the DataDog API key
   from AWS Secrets Manager into the `datadog-secret` Kubernetes secret.

## Region choice

`eu-central-1` (Frankfurt) keeps data in the EU — a baseline expectation for a
European brokerage handling customer and financial data.

## Cost note

EKS + multi-AZ RDS + NAT gateway is not free. Use `terraform destroy` after
demoing. The local kind path exists precisely so the day-to-day demo costs
nothing.
