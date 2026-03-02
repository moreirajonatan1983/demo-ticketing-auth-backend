variable "auth_lambda_invoke_arn"       { type = string }
variable "auth_lambda_function_name"    { type = string }
variable "auth_role_arn"                { type = string }
variable "generate_lambda_invoke_arn"   { type = string }
variable "generate_lambda_function_name" { type = string }
variable "environment"                  { type = string }

output "api_gateway_id" {
  value = aws_api_gateway_rest_api.auth_api.id
}

output "api_gateway_url" {
  value = aws_api_gateway_stage.auth_stage.invoke_url
}
