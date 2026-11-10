# Remote State Configuration
# Note: For production and staging environments, initialize backend with:
# terraform init -backend-config="bucket=<YOUR_TERRAFORM_STATE_BUCKET>" \
#                -backend-config="key=devops-assessment/terraform.tfstate" \
#                -backend-config="region=us-east-1" \
#                -backend-config="dynamodb_table=<YOUR_LOCK_DYNAMODB_TABLE>"

terraform {
  backend "s3" {
    bucket         = "devops-assessment-tfstate-mdalamin2526"
    key            = "state/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "devops-assessment-tflocks"
  }
}
