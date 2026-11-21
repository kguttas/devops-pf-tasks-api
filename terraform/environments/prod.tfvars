# Producción: priorizar disponibilidad (NAT por AZ, nodos on-demand, sin apagado nocturno).
environment               = "prod"
aws_region                = "us-east-1"
az_count                  = 3
single_nat_gateway        = false
node_capacity_type        = "ON_DEMAND"
node_instance_types       = ["t3.large"]
node_min_size             = 2
node_desired_size         = 3
node_max_size             = 6
enable_off_hours_schedule = false
monthly_budget_usd        = 400
