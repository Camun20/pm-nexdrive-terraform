resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project_name}-api-${var.environment}"
  description = "E-Learning Platform API"
}

# --- CloudWatch Logs for API Gateway ---
resource "aws_iam_role" "apigw_cloudwatch" {
  name = "${var.project_name}-apigw-cw-role-${var.environment}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "apigw_cloudwatch_attach" {
  role       = aws_iam_role.apigw_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch.arn
}

resource "aws_api_gateway_authorizer" "cognito" {
  name                   = "CognitoAuthorizer"
  type                   = "COGNITO_USER_POOLS"
  rest_api_id            = aws_api_gateway_rest_api.api.id
  provider_arns          = [var.user_pool_arn]
}

# --- Request Validator ---
resource "aws_api_gateway_request_validator" "validator" {
  name                        = "${var.project_name}-validator"
  rest_api_id                 = aws_api_gateway_rest_api.api.id
  validate_request_body       = true
  validate_request_parameters = true
}

# --- Internal Resources ---

# /users
resource "aws_api_gateway_resource" "users" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "users"
}

# /courses
resource "aws_api_gateway_resource" "courses" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "courses"
}

# /content
resource "aws_api_gateway_resource" "content" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "content"
}

# --- Methods ---

# POST /users
resource "aws_api_gateway_method" "post_user" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.users.id
  http_method          = "POST"
  authorization        = "NONE" # Change to NONE to allow mock admin
}

resource "aws_api_gateway_integration" "user_lambda" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.post_user.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.user_management_lambda_invoke_arn
}

# OPTIONS /users (CORS)
resource "aws_api_gateway_method" "options_users" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.users.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_users_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.options_users.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_users_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.options_users.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_users_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.users.id
  http_method = aws_api_gateway_method.options_users.http_method
  status_code = aws_api_gateway_method_response.options_users_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# POST /courses
resource "aws_api_gateway_method" "post_course" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.courses.id
  http_method          = "POST"
  authorization        = "NONE" # Change to NONE to allow mock admin
}

resource "aws_api_gateway_integration" "course_creation_lambda" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.courses.id
  http_method = aws_api_gateway_method.post_course.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.course_creation_lambda_invoke_arn
}

# GET /courses
resource "aws_api_gateway_method" "get_courses" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.courses.id
  http_method   = "GET"
  authorization = "NONE" # Change to NONE to allow mock admin
}

resource "aws_api_gateway_integration" "course_query_lambda" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.courses.id
  http_method = aws_api_gateway_method.get_courses.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.course_query_lambda_invoke_arn
}

# OPTIONS /courses (CORS)
resource "aws_api_gateway_method" "options_courses" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.courses.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_courses_integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.courses.id
  http_method = aws_api_gateway_method.options_courses.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_courses_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.courses.id
  http_method = aws_api_gateway_method.options_courses.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options_courses_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.courses.id
  http_method = aws_api_gateway_method.options_courses.http_method
  status_code = aws_api_gateway_method_response.options_courses_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}



# GET /content
resource "aws_api_gateway_method" "get_content" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.content.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "content_lambda" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.content.id
  http_method = aws_api_gateway_method.get_content.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.course_query_lambda_invoke_arn
}


# --- Gateway Responses (Error Handling) ---
resource "aws_api_gateway_gateway_response" "unauthorized" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  response_type = "UNAUTHORIZED"
  status_code   = "401"
  response_templates = {
    "application/json" = "{\"message\": \"Unauthorized. Ensure valid Cognito token.\"}"
  }
}

resource "aws_api_gateway_gateway_response" "bad_request_body" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  response_type = "BAD_REQUEST_BODY"
  status_code   = "400"
  response_templates = {
    "application/json" = "{\"message\": \"Invalid request body constraints.\"}"
  }
}

# --- Deployment ---

resource "aws_api_gateway_deployment" "api_deployment" {
  depends_on = [
    aws_api_gateway_integration.user_lambda,
    aws_api_gateway_integration.course_creation_lambda,
    aws_api_gateway_integration.course_query_lambda,
    aws_api_gateway_integration.content_lambda
  ]

  rest_api_id = aws_api_gateway_rest_api.api.id
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api_stage" {
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.environment
  
  # Method settings to enable CloudWatch logs
  depends_on = [ aws_api_gateway_account.main ]
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.api_stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

# --- Lambda Permissions ---

resource "aws_lambda_permission" "apigw_user" {
  statement_id  = "AllowExecutionFromAPIGatewayUsers"
  action        = "lambda:InvokeFunction"
  function_name = var.user_management_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_course_creation" {
  statement_id  = "AllowExecutionFromAPIGatewayCourseCreation"
  action        = "lambda:InvokeFunction"
  function_name = var.course_creation_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_course_query" {
  statement_id  = "AllowExecutionFromAPIGatewayCourseQuery"
  action        = "lambda:InvokeFunction"
  function_name = var.course_query_lambda_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

output "base_url" {
  value = aws_api_gateway_stage.api_stage.invoke_url
}

output "api_id" {
  value = aws_api_gateway_rest_api.api.id
}

variable "project_name" {}
variable "environment" {}
variable "user_pool_arn" {}
variable "user_management_lambda_arn" {}
variable "user_management_lambda_name" {}
variable "course_creation_lambda_arn" {}
variable "course_creation_lambda_name" {}
variable "course_query_lambda_arn" {}
variable "course_query_lambda_name" {}
variable "user_management_lambda_invoke_arn" {}
variable "course_creation_lambda_invoke_arn" {}
variable "course_query_lambda_invoke_arn" {}
