variable "name" {
  type        = string
  description = "Prefijo de nombres."
}

variable "project" {
  type        = string
  description = "Valor de la etiqueta Project usado para filtrar el presupuesto."
}

variable "node_group_asg_name" {
  type        = string
  description = "ASG del node group EKS."
}

variable "enable_off_hours_schedule" {
  type        = bool
  description = "Activar apagado fuera de horario."
}

variable "scale_down_cron" {
  type        = string
  description = "Cron UTC de apagado."
}

variable "scale_up_cron" {
  type        = string
  description = "Cron UTC de encendido."
}

variable "scale_up_min_size" {
  type        = number
  description = "Mínimo al encender."
}

variable "scale_up_desired_size" {
  type        = number
  description = "Deseado al encender."
}

variable "scale_up_max_size" {
  type        = number
  description = "Máximo al encender."
}

variable "monthly_budget_usd" {
  type        = number
  description = "Presupuesto mensual (0 = sin presupuesto)."
}

variable "budget_alert_emails" {
  type        = list(string)
  description = "Destinatarios de alertas."
}
