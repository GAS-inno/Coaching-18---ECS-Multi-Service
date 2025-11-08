resource "aws_sqs_queue" "message_queue" {
  name = "ecs-sqs-message-queue"
}
