resource "aws_s3_bucket" "video_content" {
  bucket = "${var.project_name}-videos-${var.environment}-pm-nexdrive-unique"
}

resource "aws_s3_bucket_cors_configuration" "video_content" {
  bucket = aws_s3_bucket.video_content.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST", "GET", "HEAD"]
    allowed_origins = [var.amplify_domain]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
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

resource "aws_dynamodb_table" "courses" {
  name         = "NexDrive-Courses-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "courseId"

  attribute {
    name = "courseId"
    type = "S"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_dynamodb_table" "evaluations" {
  name         = "NexDrive-Evaluations-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "courseId"
  range_key    = "questionId"

  attribute {
    name = "courseId"
    type = "S"
  }

  attribute {
    name = "questionId"
    type = "S"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_dynamodb_table" "users_data" {
  name         = "NexDrive-Users-Data-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"

  attribute {
    name = "email"
    type = "S"
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

output "courses_table_name" {
  value = aws_dynamodb_table.courses.name
}

output "courses_table_arn" {
  value = aws_dynamodb_table.courses.arn
}

output "evaluations_table_name" {
  value = aws_dynamodb_table.evaluations.name
}

output "evaluations_table_arn" {
  value = aws_dynamodb_table.evaluations.arn
}

output "users_data_table_name" {
  value = aws_dynamodb_table.users_data.name
}

output "users_data_table_arn" {
  value = aws_dynamodb_table.users_data.arn
}

variable "project_name" {}
variable "environment" {}
variable "amplify_domain" {}
