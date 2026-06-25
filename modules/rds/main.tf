variable "project_name" { type = string }
variable "subnet_ids"   { type = list(string) }
variable "vpc_id"       { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
variable "vpc_cidr"     { type = string }

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet"
  subnet_ids = var.subnet_ids
  tags = { Name = "${var.project_name}-db-subnet" }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "PostgreSQL access from VPC only"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "PostgreSQL from VPC internal only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}

resource "aws_db_instance" "postgres" {
  identifier            = "${var.project_name}-postgres"
  engine                = "postgres"
  engine_version        = "15"
  instance_class        = "db.t3.micro"   # FREE TIER for 12 months
  allocated_storage     = 20
  db_name               = "tire_testing"
  username              = "tire_user"
  password              = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false        # VPC internal only — NOT internet accessible
  skip_final_snapshot    = true         # For thesis — no need for final snapshot

  tags = { Name = "${var.project_name}-postgres" }
}

output "endpoint" { value = aws_db_instance.postgres.address }
output "port"     { value = aws_db_instance.postgres.port }
output "db_url" {
  value = "jdbc:postgresql://${aws_db_instance.postgres.address}:5432/tire_testing"
}
