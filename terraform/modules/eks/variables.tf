variable "cluster_name" {
  type        = string
  description = "Nombre del cluster."
}

variable "kubernetes_version" {
  type        = string
  description = "Versión de Kubernetes."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subredes privadas (nodos)."
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Subredes públicas (load balancers)."
}

variable "endpoint_public_access_cidrs" {
  type        = list(string)
  description = "CIDRs con acceso a la API pública."
}

variable "node_instance_types" {
  type        = list(string)
  description = "Tipos de instancia."
}

variable "node_capacity_type" {
  type        = string
  description = "ON_DEMAND o SPOT."
}

variable "node_min_size" {
  type        = number
  description = "Mínimo de nodos."
}

variable "node_desired_size" {
  type        = number
  description = "Nodos deseados."
}

variable "node_max_size" {
  type        = number
  description = "Máximo de nodos."
}

variable "node_disk_size" {
  type        = number
  description = "Disco por nodo (GiB)."
}

variable "log_retention_days" {
  type        = number
  default     = 7
  description = "Retención de logs del control plane."
}
