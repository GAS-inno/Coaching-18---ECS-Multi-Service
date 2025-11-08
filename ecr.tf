resource "aws_ecr_repository" "s3_service" {
  name                 = "${var.project_name}-s3-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "sqs_service" {
  name                 = "${var.project_name}-sqs-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}