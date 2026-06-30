# IRSA: bind a Kubernetes ServiceAccount to a least-privilege IAM role so the
# OTel Collector (or any pod) gets scoped AWS permissions without node-wide
# credentials. This is the IAM-best-practices piece of the JD.

variable "cluster_name"      { type = string }
variable "oidc_provider_arn" { type = string }
variable "namespace"         { type = string }
variable "service_account"   { type = string }

data "aws_iam_policy_document" "scoped" {
  statement {
    sid     = "ReadSecrets"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    # Scope to a path prefix rather than "*": least privilege.
    resources = ["arn:aws:secretsmanager:*:*:secret:lemon-brokerage/*"]
  }
}

# Role assumable only by the named ServiceAccount via the cluster OIDC provider.
# (Trust policy wiring omitted for brevity; community irsa module recommended.)
output "policy_json" { value = data.aws_iam_policy_document.scoped.json }
