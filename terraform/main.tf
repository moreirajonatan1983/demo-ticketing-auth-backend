terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {}
}

provider "aws" {
  region = "us-east-1"

  assume_role {
    role_arn     = var.target_account_role_arn
    session_name = "TerraformDeployment"
  }
}

# =====================================================================
# JWT_SECRET desde SSM Parameter Store (NO hardcodeado)
# El secreto se crea manualmente UNA VEZ por ambiente en la consola AWS
# o con: aws ssm put-parameter --name /demo-ticketing/auth/jwt_secret --value "..." --type SecureString
# =====================================================================
data "aws_ssm_parameter" "jwt_secret" {
  name            = "/demo-ticketing/${var.environment}/auth/jwt_secret"
  with_decryption = true
}

# =====================================================================
# IAM Role para las Lambdas
# =====================================================================
module "iam" {
  source    = "./modules/iam"
  role_name = "iam_for_lambda_auth_${var.environment}"
}

# =====================================================================
# Empaquetado de binarios Go (ya compilados por el CI antes de este step)
# =====================================================================
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

# =====================================================================
# Lambda: Generador de JWT
# =====================================================================
module "lambda_auth_generate" {
  source           = "./modules/lambda"
  archive_path     = data.archive_file.lambda_generate_zip.output_path
  function_name    = "demo-auth-generate-${var.environment}"
  role_arn         = module.iam.role_arn
  handler          = "bootstrap"
  source_code_hash = data.archive_file.lambda_generate_zip.output_base64sha256
  env_vars = {
    LAMBDA_HANDLER_MODE = "GENERATE_TOKEN"
    JWT_SECRET          = data.aws_ssm_parameter.jwt_secret.value
  }
}

# =====================================================================
# Lambda: Authorizer (valida JWT en cada request protegido)
# =====================================================================
module "lambda_auth_authorizer" {
  source           = "./modules/lambda"
  archive_path     = data.archive_file.lambda_authorizer_zip.output_path
  function_name    = "demo-auth-authorizer-${var.environment}"
  role_arn         = module.iam.role_arn
  handler          = "bootstrap"
  source_code_hash = data.archive_file.lambda_authorizer_zip.output_base64sha256
  env_vars = {
    LAMBDA_HANDLER_MODE = "AUTHORIZE"
    JWT_SECRET          = data.aws_ssm_parameter.jwt_secret.value
  }
}

# =====================================================================
# API Gateway (solo el /auth endpoint — eventos y tickets son del core)
# =====================================================================
module "api_gateway" {
  source                        = "./modules/api_gateway"
  environment                   = var.environment
  auth_role_arn                 = module.iam.role_arn
  auth_lambda_invoke_arn        = module.lambda_auth_authorizer.invoke_arn
  auth_lambda_function_name     = module.lambda_auth_authorizer.function_name
  generate_lambda_invoke_arn    = module.lambda_auth_generate.invoke_arn
  generate_lambda_function_name = module.lambda_auth_generate.function_name
}
