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

resource "aws_iam_role" "post_confirmation_role" {
  name               = "${var.project_name}-post-conf-role-${var.environment}"
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

resource "aws_iam_role_policy_attachment" "post_conf_logs" {
  role       = aws_iam_role.post_confirmation_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# --- Full Access Policies (Requested) ---
resource "aws_iam_role_policy_attachment" "user_mgmt_dynamo" {
  role       = aws_iam_role.user_management_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "user_mgmt_s3" {
  role       = aws_iam_role.user_management_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy" "user_mgmt_cognito" {
  name = "cognito_admin_delete"
  role = aws_iam_role.user_management_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "cognito-idp:AdminDeleteUser"
        ]
        Effect   = "Allow"
        Resource = var.user_pool_arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "course_create_dynamo" {
  role       = aws_iam_role.course_creation_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "course_create_s3" {
  role       = aws_iam_role.course_creation_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "course_query_dynamo" {
  role       = aws_iam_role.course_query_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "course_query_s3" {
  role       = aws_iam_role.course_query_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "post_conf_dynamo" {
  role       = aws_iam_role.post_confirmation_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# (Old specific policies removed as they are superseded by FullAccess managed policies)

# --- Zip Code ---
data "archive_file" "user_management_zip" {
  type        = "zip"
  source_file = "${path.module}/../../functions/user-management/index.mjs"
  output_path = "${path.module}/user_management.zip"
}

data "archive_file" "course_creation_zip" {
  type        = "zip"
  source_file = "${path.module}/../../functions/course-creation/index.mjs"
  output_path = "${path.module}/course_creation.zip"
}

data "archive_file" "course_query_zip" {
  type        = "zip"
  source_file = "${path.module}/../../functions/course-query/index.mjs"
  output_path = "${path.module}/course_query.zip"
}

data "archive_file" "post_confirmation_zip" {
  type        = "zip"
  source_file = "${path.module}/../../functions/post-confirmation/index.mjs"
  output_path = "${path.module}/post_confirmation.zip"
}

# --- Lambdas ---

# User Management Lambda
resource "aws_lambda_function" "user_management" {
  function_name = "${var.project_name}-user-management-${var.environment}"
  role          = aws_iam_role.user_management_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = data.archive_file.user_management_zip.output_path
  source_code_hash = data.archive_file.user_management_zip.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE    = var.dynamodb_table_name
      COURSES_TABLE     = var.courses_table_name
      EVALUATIONS_TABLE = var.evaluations_table_name
      USERS_DATA_TABLE  = var.users_data_table_name
      USER_POOL_ID      = var.user_pool_id
    }
  }
}

# Course Creation Lambda
resource "aws_lambda_function" "course_creation" {
  function_name = "${var.project_name}-course-creation-${var.environment}"
  role          = aws_iam_role.course_creation_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = data.archive_file.course_creation_zip.output_path
  source_code_hash = data.archive_file.course_creation_zip.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE    = var.dynamodb_table_name
      COURSES_TABLE     = var.courses_table_name
      EVALUATIONS_TABLE = var.evaluations_table_name
      S3_BUCKET         = var.video_bucket_name
    }
  }
}

# Course Query Lambda
resource "aws_lambda_function" "course_query" {
  function_name = "${var.project_name}-course-query-${var.environment}"
  role          = aws_iam_role.course_query_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = data.archive_file.course_query_zip.output_path
  source_code_hash = data.archive_file.course_query_zip.output_base64sha256

  environment {
    variables = {
      DYNAMODB_TABLE    = var.dynamodb_table_name
      COURSES_TABLE     = var.courses_table_name
      EVALUATIONS_TABLE = var.evaluations_table_name
      S3_BUCKET         = var.video_bucket_name
    }
  }
}

resource "aws_lambda_function" "post_confirmation" {
  function_name = "${var.project_name}-post-confirmation-${var.environment}"
  role          = aws_iam_role.post_confirmation_role.arn
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  filename      = data.archive_file.post_confirmation_zip.output_path
  source_code_hash = data.archive_file.post_confirmation_zip.output_base64sha256

  environment {
    variables = {
      USERS_DATA_TABLE = var.users_data_table_name
    }
  }
}

resource "aws_lambda_permission" "allow_cognito" {
  statement_id  = "AllowExecutionFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_confirmation.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = var.user_pool_arn
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

output "post_confirmation_arn" {
  value = aws_lambda_function.post_confirmation.arn
}

# --- Variables ---

variable "project_name" {}
variable "environment" {}
variable "dynamodb_table_name" {}
variable "dynamodb_table_arn" {}
variable "courses_table_name" {}
variable "courses_table_arn" {}
variable "evaluations_table_name" {}
variable "evaluations_table_arn" {}
variable "video_bucket_name" {}
variable "video_bucket_arn" {}
variable "user_pool_id" {}
variable "user_pool_arn" {}
variable "users_data_table_name" {}
variable "users_data_table_arn" {}
