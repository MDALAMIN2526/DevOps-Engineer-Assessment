variable "aws_region" {
  description = "Target AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment name (e.g., staging, production)"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be either 'staging' or 'production'."
  }
}

variable "instance_type" {
  description = "EC2 Instance type (Free Tier eligible t3.micro / t2.micro)"
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Port exposed by the web service"
  type        = number
  default     = 8080
}

variable "app_image" {
  description = "Container image URI to deploy on the EC2 instance"
  type        = string
  default     = "ghcr.io/mdalamin2526/devops-engineer-assessment:latest"
}

variable "log_retention_days" {
  description = "CloudWatch log group retention period in days"
  type        = number
  default     = 14
}

variable "ssh_allowed_cidrs" {
  description = "List of CIDR blocks permitted to connect via SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_key_name" {
  description = "Optional AWS EC2 KeyPair name for SSH access"
  type        = string
  default     = null
}
