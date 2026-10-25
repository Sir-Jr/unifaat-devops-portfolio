terraform {
  # use_lockfile (lock nativo no S3) exige Terraform >= 1.10
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # State remoto: o mesmo state é usado pelo plan (PR) e pelo apply (merge)
  # no GitHub Actions. Bucket criado por bootstrap-backend.sh.
  backend "s3" {
    bucket       = "technova-tfstate-aula10-a6c8f018"
    key          = "aula-10/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "technova"
      Aula      = "aula-10"
      ManagedBy = "terraform-gitops"
    }
  }
}
