output "s3_bucket_name" {
  value = aws_s3_bucket.uploads.bucket
}

output "sqs_queue_url" {
  value = aws_sqs_queue.messages.id
}

output "ecr_repos" {
  value = {
    s3_repo = aws_ecr_repository.s3_repo.repository_url
    sqs_repo = aws_ecr_repository.sqs_repo.repository_url
  }
}
