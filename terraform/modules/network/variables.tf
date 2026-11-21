variable "name" {
  description = "Prefijo de nombres."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR de la VPC."
  type        = string
}

variable "azs" {
  description = "Zonas de disponibilidad a usar."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Usar un único NAT Gateway compartido."
  type        = bool
  default     = true
}

variable "cluster_name" {
  description = "Nombre del cluster EKS (para etiquetar subredes y que los LB las descubran)."
  type        = string
}

variable "flow_logs_retention_days" {
  description = "Retención de los VPC flow logs."
  type        = number
  default     = 7
}
