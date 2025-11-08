resource "aws_s3_bucket" "upload_bucket" {
  bucket = "${var.project_name}-uploads-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}