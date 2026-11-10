#!/usr/bin/env bash
# ==============================================================================
# Production User Data Bootstrap Script for Ubuntu EC2 Deployment
# Note: Template variables are rendered via Terraform templatefile.
# shellcheck disable=SC2154,SC1091
# ==============================================================================
set -euo pipefail

# Export environment variables from Terraform template rendering
export AWS_DEFAULT_REGION="${aws_region}"
LOG_GROUP_NAME="${log_group_name}"
APP_IMAGE="${app_image}"
APP_PORT="${app_port}"
ENVIRONMENT="${environment}"

echo "=== [1/5] Updating packages and installing prerequisites ==="
apt-get update -y
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    awscli

echo "=== [2/5] Installing official Docker CE Engine ==="
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io docker-buildx-plugin

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

echo "=== [3/5] Authenticating to Container Registry (if ECR) ==="
if [[ "$APP_IMAGE" =~ \.amazonaws\.com ]]; then
    aws ecr get-login-password --region "$AWS_DEFAULT_REGION" | \
      docker login --username AWS --password-stdin "$APP_IMAGE" || true
fi

echo "=== [4/5] Pulling and Starting Application Container ==="
docker pull "$APP_IMAGE"

docker run -d \
    --name devops_assessment_app \
    --restart unless-stopped \
    -p "$APP_PORT":"$APP_PORT" \
    -e PORT="$APP_PORT" \
    -e LOG_LEVEL="INFO" \
    -e ENVIRONMENT="$ENVIRONMENT" \
    -e APP_VERSION="1.0.0" \
    --log-driver=awslogs \
    --log-opt awslogs-region="$AWS_DEFAULT_REGION" \
    --log-opt awslogs-group="$LOG_GROUP_NAME" \
    --log-opt awslogs-stream="ec2-$ENVIRONMENT-instance" \
    --log-opt awslogs-create-group=false \
    "$APP_IMAGE"

echo "=== [5/5] Bootstrap completed successfully ==="
