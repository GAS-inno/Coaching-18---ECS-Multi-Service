resource "aws_ecr_repository" "s3_service_repo" {
  name = "ecs-s3-service"
}

resource "aws_ecr_repository" "sqs_service_repo" {
  name = "ecs-sqs-service"
}
