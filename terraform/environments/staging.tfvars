aws_region         = "us-east-1"
environment        = "staging"
instance_type      = "t3.micro"
app_port           = 8080
app_image          = "ghcr.io/mdalamin2526/devops-engineer-assessment:latest"
log_retention_days = 7
ssh_allowed_cidrs  = ["0.0.0.0/0"]
