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
  
  # Pointing to LocalStack
  endpoints {
    apigateway     = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    cloudwatchlogs = "http://localhost:4566"
    iam            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    s3             = "http://localhost:4566"
  }
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

# --- GENERATE TOKEN LAMBDA ---
resource "aws_lambda_function" "auth_generate" {
  filename         = data.archive_file.lambda_generate_zip.output_path
  function_name    = "demo-auth-generate-tf"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "bootstrap"
  source_code_hash = data.archive_file.lambda_generate_zip.output_base64sha256
  runtime          = "provided.al2"

  environment {
    variables = {
      LAMBDA_HANDLER_MODE = "GENERATE_TOKEN"
      JWT_SECRET          = "demo-jwt-secret-local"
    }
  }
}

# --- CUSTOM AUTHORIZER LAMBDA ---
resource "aws_lambda_function" "auth_authorizer" {
  filename         = data.archive_file.lambda_authorizer_zip.output_path
  function_name    = "demo-auth-authorizer-tf"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "bootstrap"
  source_code_hash = data.archive_file.lambda_authorizer_zip.output_base64sha256
  runtime          = "provided.al2"

  environment {
    variables = {
      LAMBDA_HANDLER_MODE = "AUTHORIZE"
      JWT_SECRET          = "demo-jwt-secret-local"
    }
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda_auth"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
