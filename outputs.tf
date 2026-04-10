output "api_url" {
  value = module.api_gateway.base_url
}

output "cloudfront_url" {
  value = module.cdn.cloudfront_domain_name
}

output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_client_id" {
  value = module.cognito.client_id
}

output "dynamodb_table_name" {
  value = module.storage.dynamodb_table_name
}

output "s3_bucket_name" {
  value = module.storage.video_bucket_name
}
