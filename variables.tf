variable "aws_region" {
  description = "AWS region — Frankfurt for German industrial context"
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Prefix for all resource names"
  type        = string
  default     = "thesis"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "my_ip" {
  description = "Your public IP with /32 mask for SSH access"
  type        = string
  # Get yours: curl https://checkip.amazonaws.com
}

variable "db_password" {
  description = "RDS PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "create_eks" {
  description = "Set true ONLY during Pipeline 3 experiments. EKS costs ~€80/month."
  type        = bool
  default     = false
}
