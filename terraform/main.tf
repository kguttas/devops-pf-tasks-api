locals {
  name = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    CostCenter  = "devops-pf"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "network" {
  source = "./modules/network"

  name               = local.name
  vpc_cidr           = var.vpc_cidr
  azs                = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  single_nat_gateway = var.single_nat_gateway
  cluster_name       = local.name
}

module "eks" {
  source = "./modules/eks"

  cluster_name                 = local.name
  kubernetes_version           = var.kubernetes_version
  private_subnet_ids           = module.network.private_subnet_ids
  public_subnet_ids            = module.network.public_subnet_ids
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  node_instance_types = var.node_instance_types
  node_capacity_type  = var.node_capacity_type
  node_min_size       = var.node_min_size
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size
  node_disk_size      = var.node_disk_size
}

module "finops" {
  source = "./modules/finops"

  name                      = local.name
  project                   = var.project
  node_group_asg_name       = module.eks.node_group_asg_name
  enable_off_hours_schedule = var.enable_off_hours_schedule
  scale_down_cron           = var.off_hours_scale_down_cron
  scale_up_cron             = var.off_hours_scale_up_cron
  scale_up_min_size         = var.node_min_size
  scale_up_desired_size     = var.node_desired_size
  scale_up_max_size         = var.node_max_size
  monthly_budget_usd        = var.monthly_budget_usd
  budget_alert_emails       = var.budget_alert_emails
}

# Registry privado opcional en AWS (el pipeline usa GHCR por defecto).
resource "aws_ecr_repository" "app" {
  name                 = var.project
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.environment != "prod"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Borrar imágenes sin tag"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.ecr_untagged_expire_days
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Conservar solo las últimas 20 imágenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = { type = "expire" }
      }
    ]
  })
}
