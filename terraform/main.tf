terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "sctp-ce11-tfstate"
    key    = "yeefei-coaching-tf-ci.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# Data source for existing VPC
data "aws_vpc" "existing" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

# Data source for existing private subnets
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

# Data source for existing public subnets
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*public*"]
  }
}

# S3 Bucket for file uploads
resource "aws_s3_bucket" "uploads" {
  bucket = "${var.project_name}-uploads-${data.aws_caller_identity.current.account_id}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-uploads"
  })
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SQS Queue
resource "aws_sqs_queue" "messages" {
  name                       = "${var.project_name}-messages"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 10

  tags = merge(var.tags, {
    Name = "${var.project_name}-messages"
  })
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.public.ids

  enable_deletion_protection = false

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb"
  })
}

# ALB Target Groups
resource "aws_lb_target_group" "s3_service" {
  name        = "${var.project_name}-s3-tg"
  port        = 5001
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.existing.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,404"
    path                = "/upload"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-s3-tg"
  })
}

resource "aws_lb_target_group" "sqs_service" {
  name        = "${var.project_name}-sqs-tg"
  port        = 5002
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.existing.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,404"
    path                = "/send"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  deregistration_delay = 30

  tags = merge(var.tags, {
    Name = "${var.project_name}-sqs-tg"
  })
}

# ALB Listeners
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Service not found"
      status_code  = "404"
    }
  }
}

# ALB Listener Rules
resource "aws_lb_listener_rule" "s3_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.s3_service.arn
  }

  condition {
    path_pattern {
      values = ["/upload*"]
    }
  }
}

resource "aws_lb_listener_rule" "sqs_service" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sqs_service.arn
  }

  condition {
    path_pattern {
      values = ["/send*"]
    }
  }
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb-sg"
  })
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-ecs-tasks-sg"
  })
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Tasks (Application permissions)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# S3 Service Task Role Policy
resource "aws_iam_role_policy" "s3_service_policy" {
  name = "${var.project_name}-s3-service-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.uploads.arn,
          "${aws_s3_bucket.uploads.arn}/*"
        ]
      }
    ]
  })
}

# SQS Service Task Role Policy
resource "aws_iam_role_policy" "sqs_service_policy" {
  name = "${var.project_name}-sqs-service-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.messages.arn
      }
    ]
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "s3_service" {
  name              = "/ecs/${var.project_name}/s3-service"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.project_name}-s3-service-logs"
  })
}

resource "aws_cloudwatch_log_group" "sqs_service" {
  name              = "/ecs/${var.project_name}/sqs-service"
  retention_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.project_name}-sqs-service-logs"
  })
}

# Data source for current AWS account
data "aws_caller_identity" "current" {}

# ECS Task Definitions
resource "aws_ecs_task_definition" "s3_service" {
  family                   = "${var.project_name}-s3-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "s3-app"
      image     = var.s3_service_image
      essential = true
      portMappings = [
        {
          containerPort = 5001
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "BUCKET_NAME"
          value = aws_s3_bucket.uploads.id
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.s3_service.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(var.tags, {
    Service = "s3-service"
  })
}

resource "aws_ecs_task_definition" "sqs_service" {
  family                   = "${var.project_name}-sqs-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "sqs-app"
      image     = var.sqs_service_image
      essential = true
      portMappings = [
        {
          containerPort = 5002
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "QUEUE_URL"
          value = aws_sqs_queue.messages.url
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.sqs_service.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = merge(var.tags, {
    Service = "sqs-service"
  })
}

# ECS Cluster with services
module "ecs" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.9.0"

  cluster_name = "${var.project_name}-cluster"

  # Fargate capacity providers
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

      # Reference existing task definition
      task_definition_arn = aws_ecs_task_definition.s3_service.arn

      # Load balancer configuration
      load_balancer = {
        service = {
          target_group_arn = aws_lb_target_group.s3_service.arn
          container_name   = "s3-app"
          container_port   = 5001
        }
      }

      # Network configuration
      subnet_ids = data.aws_subnets.private.ids
      security_group_rules = {
        alb_ingress = {
          type                     = "ingress"
          from_port                = 5001
          to_port                  = 5001
          protocol                 = "tcp"
          source_security_group_id = aws_security_group.alb.id
        }
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }

      # Task definition
      create_task_definition       = false
      requires_compatibilities     = ["FARGATE"]
      create_task_exec_iam_role    = false
      task_exec_iam_role_arn       = aws_iam_role.ecs_task_execution_role.arn
      create_tasks_iam_role        = false
      tasks_iam_role_arn           = aws_iam_role.ecs_task_role.arn

      # Service configuration
      desired_count = 1
      
      tags = merge(var.tags, {
        Service = "s3-service"
      })
    }

    sqs-service = {
      cpu    = 256
      memory = 512

      # Reference existing task definition
      task_definition_arn = aws_ecs_task_definition.sqs_service.arn

      # Load balancer configuration
      load_balancer = {
        service = {
          target_group_arn = aws_lb_target_group.sqs_service.arn
          container_name   = "sqs-app"
          container_port   = 5002
        }
      }

      # Network configuration
      subnet_ids = data.aws_subnets.private.ids
      security_group_rules = {
        alb_ingress = {
          type                     = "ingress"
          from_port                = 5002
          to_port                  = 5002
          protocol                 = "tcp"
          source_security_group_id = aws_security_group.alb.id
        }
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }

      # Task definition
      create_task_definition       = false
      requires_compatibilities     = ["FARGATE"]
      create_task_exec_iam_role    = false
      task_exec_iam_role_arn       = aws_iam_role.ecs_task_execution_role.arn
      create_tasks_iam_role        = false
      tasks_iam_role_arn           = aws_iam_role.ecs_task_role.arn

      # Service configuration
      desired_count = 1
      
      tags = merge(var.tags, {
        Service = "sqs-service"
      })
    }
  }

  tags = var.tags
}
