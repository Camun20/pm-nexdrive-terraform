provider "aws" {
  region = var.aws_region
}

module "storage" {
  source         = "./modules/storage"
  project_name   = var.project_name
  environment    = var.environment
  amplify_domain = var.amplify_domain
}

module "cognito" {
  source       = "./modules/cognito"
  project_name = var.project_name
  environment  = var.environment
}

module "lambda" {
  source                 = "./modules/lambda"
  project_name           = var.project_name
  environment            = var.environment
  dynamodb_table_name    = module.storage.dynamodb_table_name
  dynamodb_table_arn     = module.storage.dynamodb_table_arn
  courses_table_name     = module.storage.courses_table_name
  courses_table_arn      = module.storage.courses_table_arn
  evaluations_table_name = module.storage.evaluations_table_name
  evaluations_table_arn  = module.storage.evaluations_table_arn
  video_bucket_name      = module.storage.video_bucket_name
  video_bucket_arn       = module.storage.video_bucket_arn
  user_pool_id           = module.cognito.user_pool_id
}

module "api_gateway" {
  source                      = "./modules/api_gateway"
  project_name                = var.project_name
  environment                 = var.environment
  user_pool_arn               = module.cognito.user_pool_arn
  user_management_lambda_arn  = module.lambda.user_management_arn
  user_management_lambda_name = module.lambda.user_management_name
  course_creation_lambda_arn  = module.lambda.course_creation_arn
  course_creation_lambda_name       = module.lambda.course_creation_name
  course_query_lambda_arn           = module.lambda.course_query_arn
  course_query_lambda_name          = module.lambda.course_query_name
  user_management_lambda_invoke_arn = module.lambda.user_management_invoke_arn
  course_creation_lambda_invoke_arn = module.lambda.course_creation_invoke_arn
  course_query_lambda_invoke_arn    = module.lambda.course_query_invoke_arn
}

module "cdn" {
  source                            = "./modules/cdn"
  project_name                      = var.project_name
  environment                       = var.environment
  api_id                            = module.api_gateway.api_id
  aws_region                        = var.aws_region
  video_bucket_id                   = module.storage.video_bucket_id
  video_bucket_arn                  = module.storage.video_bucket_arn
  video_bucket_regional_domain_name = module.storage.video_bucket_regional_domain_name
}
