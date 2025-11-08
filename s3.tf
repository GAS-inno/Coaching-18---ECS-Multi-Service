resource "aws_s3_bucket" "upload_bucket" {
  bucket = "ecs-s3-upload-bucket-${random_id.suffix.hex}"
}

resource "random_id" "suffix" {
  byte_length = 4
}
