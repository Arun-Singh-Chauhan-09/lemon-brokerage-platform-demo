# VPC for the EKS cluster. Uses the community module; two AZs minimum so the
# cluster and RDS can run multi-AZ. Stubbed for the documented EKS path.

variable "vpc_cidr"    { type = string }
variable "environment" { type = string }

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "lemon-brokerage-${var.environment}"
  cidr = var.vpc_cidr

  azs             = ["eu-central-1a", "eu-central-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true   # cost control for a demo; HA NAT in real prod.

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

output "vpc_id"          { value = module.vpc.vpc_id }
output "private_subnets" { value = module.vpc.private_subnets }
