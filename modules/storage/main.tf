resource "aws_s3_bucket" "video_content" {
  bucket = "${var.project_name}-videos-${var.environment}-pm-nexdrive-unique"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "video_content_sse" {
  bucket = aws_s3_bucket.video_content.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "video_content" {
  bucket = aws_s3_bucket.video_content.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "metadata" {
  name         = "${var.project_name}-metadata-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  global_secondary_index {
    name               = "GSI1"
    hash_key           = "GSI1PK"
    range_key          = "GSI1SK"
    projection_type    = "ALL"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

output "video_bucket_id" {
  value = aws_s3_bucket.video_content.id
}

output "video_bucket_name" {
  value = aws_s3_bucket.video_content.bucket
}

output "video_bucket_arn" {
  value = aws_s3_bucket.video_content.arn
}

output "video_bucket_regional_domain_name" {
  value = aws_s3_bucket.video_content.bucket_regional_domain_name
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.metadata.name
}

output "dynamodb_table_arn" {
  value = aws_dynamodb_table.metadata.arn
}

variable "project_name" {}
variable "environment" {}
