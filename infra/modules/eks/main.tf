# EKS cluster module (documented, not applied by the local demo).
# Uses the community terraform-aws-modules to stay close to production
# practice rather than hand-rolling control-plane wiring.

variable "cluster_name" { type = string }
variable "vpc_id"       { type = string }
variable "subnet_ids"   { type = list(string) }
variable "environment"  { type = string }

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  # Private endpoint by default; public access tightly scoped in real use.
  cluster_endpoint_public_access = true

  enable_irsa = true   # IAM Roles for Service Accounts — least-privilege pods.

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "lemon-brokerage-demo"
  }
}

output "cluster_name"     { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "oidc_provider_arn" { value = module.eks.oidc_provider_arn }
