# environments/staging/terraform.tfvars — ambiente STAGING
# A senha do banco NÃO fica aqui: export TF_VAR_db_password="..."

project_name = "technova"
environment  = "staging"
vpc_cidr     = "10.1.0.0/16"

subnets = {
  "public-1"  = { cidr = "10.1.1.0/24", az = "us-east-1a", type = "public" }
  "public-2"  = { cidr = "10.1.2.0/24", az = "us-east-1b", type = "public" }
  "private-1" = { cidr = "10.1.3.0/24", az = "us-east-1a", type = "private" }
  "private-2" = { cidr = "10.1.4.0/24", az = "us-east-1b", type = "private" }
}

db_name = "technova_staging"
