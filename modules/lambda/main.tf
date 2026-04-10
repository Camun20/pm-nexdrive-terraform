# Base Assume Role Policy
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# --- Roles ---
resource "aws_iam_role" "user_management_role" {
  name               = "${var.project_name}-user-mgmt-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role" "course_creation_role" {
  name               = "${var.project_name}-course-create-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role" "course_query_role" {
  name               = "${var.project_name}-course-query-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# --- Basic Execution (Logs) ---
resource "aws_iam_role_policy_attachment" "user_mgmt_logs" {
  role       = aws_iam_role.user_management_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "course_create_logs" {
  role       = aws_iam_role.course_creation_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "course_query_logs" {
  role       = aws_iam_role.course_query_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- Specific Policies ---
# User Management: DB Read/Write
resource "aws_iam_policy" "user_mgmt_policy" {
  name        = "${var.project_name}-user-mgmt-policy-${var.environment}"
  description = "DynamoDB read/write access for User Management"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = [var.dynamodb_table_arn, "${var.dynamodb_table_arn}/index/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "user_mgmt_attach" {
  role       = aws_iam_role.user_management_role.name
  policy_arn = aws_iam_policy.user_mgmt_policy.arn
}

# Course Creation: DB Read/Write + S3 Put (for Presigned URLs generation or uploads)
resource "aws_iam_policy" "course_create_policy" {
  name        = "${var.project_name}-course-create-policy-${var.environment}"
  description = "DynamoDB read/write and S3 put access for Course Creation"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query"
        ]
        Effect   = "Allow"
        Resource = [var.dynamodb_table_arn, "${var.dynamodb_table_arn}/index/*"]
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = "${var.video_bucket_arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "course_create_attach" {
  role       = aws_iam_role.course_creation_role.name
  policy_arn = aws_iam_policy.course_create_policy.arn
}

# Course Query: DB Read Only + S3 GetObject (if presigned get urls are needed)
resource "aws_iam_policy" "course_query_policy" {
  name        = "${var.project_name}-course-query-policy-${var.environment}"
  description = "DynamoDB read and S3 read for Course Query"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = [var.dynamodb_table_arn, "${var.dynamodb_table_arn}/index/*"]
      },
      {
        Action = [
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = "${var.video_bucket_arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "course_query_attach" {
  role       = aws_iam_role.course_query_role.name
  policy_arn = aws_iam_policy.course_query_policy.arn
}

# --- Lambdas ---

# User Management Lambda
resource "aws_lambda_function" "user_management" {
  function_name = "${var.project_name}-user-management-${var.environment}"
  role          = aws_iam_role.user_management_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "${path.module}/dummy.zip" # Placeholder

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      USER_POOL_ID   = var.user_pool_id
    }
  }
}

# Course Creation Lambda
resource "aws_lambda_function" "course_creation" {
  function_name = "${var.project_name}-course-creation-${var.environment}"
  role          = aws_iam_role.course_creation_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "${path.module}/dummy.zip" # Placeholder

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      S3_BUCKET      = var.video_bucket_name
    }
  }
}

# Course Query Lambda
resource "aws_lambda_function" "course_query" {
  function_name = "${var.project_name}-course-query-${var.environment}"
  role          = aws_iam_role.course_query_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = "${path.module}/dummy.zip" # Placeholder

  environment {
    variables = {
      DYNAMODB_TABLE = var.dynamodb_table_name
      S3_BUCKET      = var.video_bucket_name
    }
  }
}

# --- CloudWatch Log Groups ---

resource "aws_cloudwatch_log_group" "user_management" {
  name              = "/aws/lambda/${aws_lambda_function.user_management.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "course_creation" {
  name              = "/aws/lambda/${aws_lambda_function.course_creation.function_name}"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "course_query" {
  name              = "/aws/lambda/${aws_lambda_function.course_query.function_name}"
  retention_in_days = 14
}

# --- Outputs ---

output "user_management_arn" {
  value = aws_lambda_function.user_management.arn
}

output "user_management_name" {
  value = aws_lambda_function.user_management.function_name
}

output "course_creation_arn" {
  value = aws_lambda_function.course_creation.arn
}

output "course_creation_name" {
  value = aws_lambda_function.course_creation.function_name
}

output "course_query_arn" {
  value = aws_lambda_function.course_query.arn
}

output "course_query_name" {
  value = aws_lambda_function.course_query.function_name
}

output "user_management_invoke_arn" {
  value = aws_lambda_function.user_management.invoke_arn
}

output "course_creation_invoke_arn" {
  value = aws_lambda_function.course_creation.invoke_arn
}

output "course_query_invoke_arn" {
  value = aws_lambda_function.course_query.invoke_arn
}

# --- Variables ---

variable "project_name" {}
variable "environment" {}
variable "dynamodb_table_name" {}
variable "dynamodb_table_arn" {}
variable "video_bucket_name" {}
variable "video_bucket_arn" {}
variable "user_pool_id" {}
