resource "aws_cognito_user_pool" "pool" {
  name = "${var.project_name}-user-pool-${var.environment}"

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  schema {
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    name                     = "email"
    required                 = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  auto_verified_attributes = ["email"]
  
  lambda_config {
    post_confirmation = var.post_confirmation_lambda_arn
  }
}

resource "aws_cognito_user_pool_client" "client" {
  name = "${var.project_name}-client-${var.environment}"

  user_pool_id = aws_cognito_user_pool.pool.id
  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]
}

output "user_pool_id" {
  value = aws_cognito_user_pool.pool.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.pool.arn
}

output "client_id" {
  value = aws_cognito_user_pool_client.client.id
}

variable "project_name" {}
variable "environment" {}
variable "post_confirmation_lambda_arn" {}
