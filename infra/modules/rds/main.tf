# Encrypted Postgres for the brokerage API's persistent state.
# storage_encrypted = true is the control a regulated broker cares about;
# tfsec/Checkov will flag it if ever turned off.

variable "identifier"   { type = string }
variable "subnet_ids"   { type = list(string) }
variable "vpc_id"       { type = string }
variable "environment"  { type = string }

resource "aws_db_subnet_group" "this" {
  name       = "${var.identifier}-subnets"
  subnet_ids = var.subnet_ids
}

resource "aws_db_instance" "this" {
  identifier     = var.identifier
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_encrypted = true          # <-- the compliance control
  kms_key_id        = null          # use default aws/rds KMS key for demo

  db_subnet_group_name = aws_db_subnet_group.this.name

  username = "brokerage"
  manage_master_user_password = true  # secret managed in Secrets Manager

  multi_az                = true       # availability
  backup_retention_period = 7
  deletion_protection     = true
  skip_final_snapshot     = false
  final_snapshot_identifier = "${var.identifier}-final"

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

output "endpoint" { value = aws_db_instance.this.endpoint }
