variable "project" {
  description = "Nombre del proyecto; prefijo de todos los recursos."
  type        = string
  default     = "tasks-api"
}

variable "environment" {
  description = "Entorno (dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment debe ser dev, staging o prod."
  }
}

variable "owner" {
  description = "Responsable del gasto (etiqueta Owner)."
  type        = string
  default     = "devops-team"
}

variable "aws_region" {
  description = "Región AWS."
  type        = string
  default     = "us-east-1"
}

# ---------------- Red ----------------
variable "vpc_cidr" {
  description = "CIDR de la VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "az_count" {
  description = "Número de zonas de disponibilidad (EKS exige al menos 2)."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count debe estar entre 2 y 3."
  }
}

variable "single_nat_gateway" {
  description = "FinOps: un único NAT Gateway compartido (más barato) en vez de uno por AZ."
  type        = bool
  default     = true
}

# ---------------- EKS ----------------
variable "kubernetes_version" {
  description = "Versión de Kubernetes del control plane EKS."
  type        = string
  default     = "1.33"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDRs autorizados a la API pública del cluster. Restringir en entornos reales."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  description = "Tipos de instancia del node group (varios tipos mejoran la disponibilidad de Spot)."
  type        = list(string)
  default     = ["t3.medium", "t3a.medium"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND o SPOT. SPOT reduce el costo de cómputo hasta ~70% (FinOps)."
  type        = string
  default     = "SPOT"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type debe ser ON_DEMAND o SPOT."
  }
}

variable "node_min_size" {
  type        = number
  default     = 1
  description = "Mínimo de nodos."
}

variable "node_desired_size" {
  type        = number
  default     = 2
  description = "Nodos deseados al crear el node group."
}

variable "node_max_size" {
  type        = number
  default     = 4
  description = "Máximo de nodos (techo de gasto)."
}

variable "node_disk_size" {
  type        = number
  default     = 20
  description = "Disco por nodo en GiB."
}

# ---------------- FinOps ----------------
variable "enable_off_hours_schedule" {
  description = "Apaga los nodos fuera de horario laboral (scale to 0) y los enciende en la mañana."
  type        = bool
  default     = true
}

variable "off_hours_scale_down_cron" {
  description = "Cron (UTC) de apagado. Por defecto 23:00 UTC (20:00 Chile verano) de lunes a viernes."
  type        = string
  default     = "0 23 * * MON-FRI"
}

variable "off_hours_scale_up_cron" {
  description = "Cron (UTC) de encendido. Por defecto 11:00 UTC (08:00 Chile verano) de lunes a viernes."
  type        = string
  default     = "0 11 * * MON-FRI"
}

variable "monthly_budget_usd" {
  description = "Presupuesto mensual en USD; 0 desactiva la creación del budget."
  type        = number
  default     = 50
}

variable "budget_alert_emails" {
  description = "Correos que reciben las alertas del presupuesto."
  type        = list(string)
  default     = []
}

variable "ecr_untagged_expire_days" {
  description = "Días tras los cuales se borran imágenes sin tag del ECR (ahorro de almacenamiento)."
  type        = number
  default     = 7
}
