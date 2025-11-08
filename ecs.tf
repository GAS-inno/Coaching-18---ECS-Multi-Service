module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.9.0"

  cluster_name = "ecs-demo-cluster"

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  services = {
    s3-service = {
      container_definitions = jsonencode([
        {
          name      = "s3-service"
          image     = "${aws_ecr_repository.s3_repo.repository_url}:latest"
          cpu       = 256
          memory    = 512
          essential = true
          portMappings = [{ containerPort = 5001 }]
          environment = [
            { name = "AWS_REGION", value = "ap-southeast-1" },
            { name = "BUCKET_NAME", value = aws_s3_bucket.uploads.bucket }
          ]
        }
      ])
    }

    sqs-service = {
      container_definitions = jsonencode([
        {
          name      = "sqs-service"
          image     = "${aws_ecr_repository.sqs_repo.repository_url}:latest"
          cpu       = 256
          memory    = 512
          essential = true
          portMappings = [{ containerPort = 5002 }]
          environment = [
            { name = "AWS_REGION", value = "ap-southeast-1" },
            { name = "QUEUE_URL", value = aws_sqs_queue.messages.id }
          ]
        }
      ])
    }
  }
}
