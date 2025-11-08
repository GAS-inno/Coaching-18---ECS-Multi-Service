module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.9.0"

  cluster_name = "${var.project_name}-cluster"

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  services = {
    s3-service = {
      cpu    = 256
      memory = 512

      container_definitions = {
        s3-app = {
          name      = "s3-app"
          essential = true
          image     = "${aws_ecr_repository.s3_service.repository_url}:latest"
          port_mappings = [{
            containerPort = 5001
            protocol      = "tcp"
          }]
          environment = [
            {
              name  = "AWS_REGION"
              value = var.aws_region
            },
            {
              name  = "BUCKET_NAME"
              value = aws_s3_bucket.upload_bucket.id
            }
          ]
        }
      }

      subnet_ids         = data.aws_subnets.default.ids
      assign_public_ip   = true
      task_exec_iam_role_arn = aws_iam_role.ecs_task_execution_role.arn
      tasks_iam_role_arn = aws_iam_role.s3_task_role.arn
    }

    sqs-service = {
      cpu    = 256
      memory = 512

      container_definitions = {
        sqs-app = {
          name      = "sqs-app"
          essential = true
          image     = "${aws_ecr_repository.sqs_service.repository_url}:latest"
          port_mappings = [{
            containerPort = 5002
            protocol      = "tcp"
          }]
          environment = [
            {
              name  = "AWS_REGION"
              value = var.aws_region
            },
            {
              name  = "QUEUE_URL"
              value = aws_sqs_queue.message_queue.url
            }
          ]
        }
      }

      subnet_ids         = data.aws_subnets.default.ids
      assign_public_ip   = true
      task_exec_iam_role_arn = aws_iam_role.ecs_task_execution_role.arn
      tasks_iam_role_arn = aws_iam_role.sqs_task_role.arn
    }
  }
}