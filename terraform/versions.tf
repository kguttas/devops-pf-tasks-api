terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Estado remoto en S3 con bloqueo nativo (use_lockfile, Terraform >= 1.10).
  # La configuración concreta (bucket, key, región) se pasa en `terraform init`
  # con -backend-config=backend.hcl para no fijar datos de la cuenta en el código.
  # El bucket se crea una sola vez con terraform/bootstrap.
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  # Etiquetas obligatorias en TODOS los recursos: base del showback de costos (FinOps).
  default_tags {
    tags = local.common_tags
  }
}
