terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "thesis-terraform-state-rashed-2026"
    key     = "thesis/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "MastersThesis"
      Owner     = "Rashed"
      ManagedBy = "Terraform"
    }
  }
}

module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  my_ip        = var.my_ip
}

module "ecr" {
  source          = "./modules/ecr"
  repository_name = "tire-testing"
}

module "ec2" {
  source             = "./modules/ec2"
  project_name       = var.project_name
  subnet_id          = module.networking.public_subnet_id
  security_group_id  = module.networking.ec2_sg_id
  key_name           = var.key_name
  ami_id             = "ami-0faab6bdbac9486fb"  # Ubuntu 22.04 eu-central-1
  ecr_repository_arn = module.ecr.repository_arn
}

module "eks" {
  source             = "./modules/eks"
  create_eks         = var.create_eks
  project_name       = var.project_name
  subnet_ids         = [
    module.networking.public_subnet_id
  ]
  node_instance_type = "t3.medium"
  eks_version        = "1.29"
}

data "aws_caller_identity" "current" {}
