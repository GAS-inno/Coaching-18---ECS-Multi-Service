# ==================================================
# ECS Task Execution Role
# Used by ECS to pull images from ECR and write logs
# ==================================================
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-ecs-task-execution-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ==================================================
# S3 Service Task Role
# Used by the application to access S3
# ==================================================
resource "aws_iam_role" "s3_task_role" {
  name = "${var.project_name}-s3-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-s3-task-role"
    Environment = var.environment
    Service     = "s3-service"
  }
}

resource "aws_iam_role_policy" "s3_task_policy" {
  name = "${var.project_name}-s3-access-policy"
  role = aws_iam_role.s3_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:DeleteObject"
      ]
      Resource = [
        aws_s3_bucket.upload_bucket.arn,
        "${aws_s3_bucket.upload_bucket.arn}/*"
      ]
    }]
  })
}

# ==================================================
# SQS Service Task Role
# Used by the application to access SQS
# ==================================================
resource "aws_iam_role" "sqs_task_role" {
  name = "${var.project_name}-sqs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.project_name}-sqs-task-role"
    Environment = var.environment
    Service     = "sqs-service"
  }
}

resource "aws_iam_role_policy" "sqs_task_policy" {
  name = "${var.project_name}-sqs-access-policy"
  role = aws_iam_role.sqs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl"
      ]
      Resource = [
        aws_sqs_queue.message_queue.arn,
        aws_sqs_queue.message_queue_dlq.arn
      ]
    }]
  })
}