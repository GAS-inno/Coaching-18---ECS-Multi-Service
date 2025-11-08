output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "s3_service_url" {
  description = "URL for the S3 service"
  value       = "http://${aws_lb.main.dns_name}/upload"
}

output "sqs_service_url" {
  description = "URL for the SQS service"
  value       = "http://${aws_lb.main.dns_name}/send"
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for uploads"
  value       = aws_s3_bucket.uploads.id
}

output "sqs_queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.messages.url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "s3_service_name" {
  description = "Name of the S3 ECS service"
  value       = module.ecs.services["s3-service"].name
}

output "sqs_service_name" {
  description = "Name of the SQS ECS service"
  value       = module.ecs.services["sqs-service"].name
}
