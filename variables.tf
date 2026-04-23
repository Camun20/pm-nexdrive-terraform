variable "aws_region" {
  description = "The AWS region to deploy to."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project."
  type        = string
  default     = "e-learning-platform"
}

variable "environment" {
  description = "The environment name (e.g. dev, prod)."
  type        = string
  default     = "dev"
}

variable "amplify_domain" {
  description = "The domain of the Amplify application for CORS."
  type        = string
  default     = "https://main.d3dhvqli97edsu.amplifyapp.com"
}
