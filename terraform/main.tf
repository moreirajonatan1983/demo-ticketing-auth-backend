terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # Pointing to LocalStack (for local dev)
  endpoints {
    apigateway     = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    cloudwatchlogs = "http://localhost:4566"
    iam            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    s3             = "http://localhost:4566"
  }
}

module "iam" {
  source    = "./modules/iam"
  role_name = "iam_for_lambda_auth"
}

data "archive_file" "lambda_generate_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/auth-generate/bootstrap"
  output_path = "${path.module}/auth_generate.zip"
}

data "archive_file" "lambda_authorizer_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambdas/auth-authorizer/bootstrap"
  output_path = "${path.module}/auth_authorizer.zip"
}

module "lambda_auth_generate" {
  source           = "./modules/lambda"
  archive_path     = data.archive_file.lambda_generate_zip.output_path
  function_name    = "demo-auth-generate-tf"
  role_arn         = module.iam.role_arn
  handler          = "bootstrap"
  source_code_hash = data.archive_file.lambda_generate_zip.output_base64sha256
  env_vars = {
    LAMBDA_HANDLER_MODE = "GENERATE_TOKEN"
    JWT_SECRET          = "demo-jwt-secret-local"
  }
}

module "lambda_auth_authorizer" {
  source           = "./modules/lambda"
  archive_path     = data.archive_file.lambda_authorizer_zip.output_path
  function_name    = "demo-auth-authorizer-tf"
  role_arn         = module.iam.role_arn
  handler          = "bootstrap"
  source_code_hash = data.archive_file.lambda_authorizer_zip.output_base64sha256
  env_vars = {
    LAMBDA_HANDLER_MODE = "AUTHORIZE"
    JWT_SECRET          = "demo-jwt-secret-local"
  }
}

module "api_gateway" {
  source                     = "./modules/api_gateway"
  auth_role_arn              = module.iam.role_arn
  auth_lambda_invoke_arn     = module.lambda_auth_authorizer.invoke_arn
  generate_lambda_invoke_arn = module.lambda_auth_generate.invoke_arn
}
