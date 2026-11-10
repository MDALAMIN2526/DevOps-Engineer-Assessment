aws_region         = "us-east-1"
environment        = "production"
instance_type      = "t3.small"
app_port           = 8080
app_image          = "ghcr.io/mdalamin2526/devops-engineer-assessment:latest"
log_retention_days = 30
ssh_allowed_cidrs  = ["10.0.0.0/8"]
