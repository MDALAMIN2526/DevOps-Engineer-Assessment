output "instance_id" {
  description = "ID of the deployed EC2 instance"
  value       = aws_instance.app_server.id
}

output "instance_public_ip" {
  description = "Public IPv4 address of the EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "app_url" {
  description = "Direct HTTP URL to the deployed web service"
  value       = "http://${aws_instance.app_server.public_ip}:${var.app_port}"
}

output "health_endpoint" {
  description = "Health check URL of the deployed web service"
  value       = "http://${aws_instance.app_server.public_ip}:${var.app_port}/health"
}

output "metrics_endpoint" {
  description = "Prometheus metrics URL of the deployed web service"
  value       = "http://${aws_instance.app_server.public_ip}:${var.app_port}/metrics"
}

output "security_group_id" {
  description = "ID of the security group attached to the instance"
  value       = aws_security_group.app_sg.id
}

output "iam_role_arn" {
  description = "ARN of the IAM role assigned to the instance profile"
  value       = aws_iam_role.app_role.arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group receiving container stdout/stderr logs"
  value       = aws_cloudwatch_log_group.app_logs.name
}
