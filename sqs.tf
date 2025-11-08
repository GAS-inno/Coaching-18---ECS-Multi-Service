resource "aws_sqs_queue" "message_queue" {
  name                      = "${var.project_name}-messages"
  message_retention_seconds = 345600
  visibility_timeout_seconds = 30
}

resource "aws_sqs_queue" "message_queue_dlq" {
  name                      = "${var.project_name}-messages-dlq"
  message_retention_seconds = 1209600
  visibility_timeout_seconds = 30
}