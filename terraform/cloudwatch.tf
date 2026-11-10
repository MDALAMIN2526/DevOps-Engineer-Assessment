# CloudWatch Log Group for Application Container Logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/ec2/${var.environment}-devops-assessment-app"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.environment}-app-log-group"
    Environment = var.environment
  }
}
