variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name to be used as a prefix for all resources"
  type        = string
  default     = "ecs-multi-service"
}

variable "vpc_name" {
  description = "Name of the existing VPC to use"
  type        = string
  default     = "ce11-tf-vpc-97"
}

variable "s3_service_image" {
  description = "Docker image for S3 service"
  type        = string
  # Update this with your ECR repository URL or Docker Hub image
  # Example: "123456789012.dkr.ecr.us-east-1.amazonaws.com/s3-service:latest"
}

variable "sqs_service_image" {
  description = "Docker image for SQS service"
  type        = string
  # Update this with your ECR repository URL or Docker Hub image
  # Example: "123456789012.dkr.ecr.us-east-1.amazonaws.com/sqs-service:latest"
}

variable "tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default = {
    Project     = "ECS-Multi-Service"
    Environment = "Development"
    ManagedBy   = "Terraform"
  }
}
