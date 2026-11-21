# Entorno de pruebas: priorizar costo sobre disponibilidad.
environment               = "dev"
aws_region                = "us-east-1"
az_count                  = 2
single_nat_gateway        = true
node_capacity_type        = "SPOT"
node_instance_types       = ["t3.medium", "t3a.medium"]
node_min_size             = 1
node_desired_size         = 2
node_max_size             = 3
enable_off_hours_schedule = true
monthly_budget_usd        = 50
