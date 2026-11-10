# Discover Default VPC
data "aws_vpc" "default" {
  default = true
}

# Discover Subnets in Default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Discover Latest Official Ubuntu 24.04 LTS (Noble Numbat) AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group exposing only required ingress ports (Port 8080 and restricted SSH)
resource "aws_security_group" "app_sg" {
  name        = "${var.environment}-devops-app-sg"
  description = "Security group for DevOps Assessment Web Service on EC2"
  vpc_id      = data.aws_vpc.default.id

  # Application port
  ingress {
    description      = "Inbound HTTP application traffic"
    from_port        = var.app_port
    to_port          = var.app_port
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # SSH port (restricted)
  ingress {
    description = "Restricted inbound SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }

  # All outbound traffic allowed
  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${var.environment}-app-security-group"
    Environment = var.environment
  }
}

# EC2 Instance Resource
resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.app_profile.name
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/scripts/userdata.sh", {
    aws_region     = var.aws_region
    log_group_name = aws_cloudwatch_log_group.app_logs.name
    app_image      = var.app_image
    app_port       = var.app_port
    environment    = var.environment
  })

  tags = {
    Name        = "${var.environment}-devops-app-server"
    Environment = var.environment
    Service     = "assessment-web-service"
  }
}
