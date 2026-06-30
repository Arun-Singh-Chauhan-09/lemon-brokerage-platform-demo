# Real EKS path. See docs/eks-migration.md before running `terraform apply`.
environment  = "demo"
region       = "eu-central-1"   # Frankfurt — EU data residency
cluster_name = "lemon-brokerage-demo"
vpc_cidr     = "10.0.0.0/16"
