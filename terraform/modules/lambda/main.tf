resource "aws_lambda_function" "this" {
  filename         = var.archive_path
  function_name    = var.function_name
  role             = var.role_arn
  handler          = var.handler
  source_code_hash = var.source_code_hash
  runtime          = "provided.al2"

  environment {
    variables = var.env_vars
  }
}
