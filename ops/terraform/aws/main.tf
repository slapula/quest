provider "aws" {
  region = local.region
}

locals {
  name            = "rearc-quest"
  cluster_version = "1.21"
  region          = "us-east-1"
}

terraform {
  backend "s3" {
    encrypt        = true
    bucket         = "rearc-quest-tfstate"
    key            = "aws/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "rearcquest"
  }
}

data "aws_availability_zones" "available" {}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}
