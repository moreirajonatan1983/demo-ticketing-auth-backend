variable "auth_lambda_invoke_arn" { type = string }
variable "auth_role_arn" { type = string }
variable "generate_lambda_invoke_arn" { type = string }

output "api_gateway_id" {
  value = aws_api_gateway_rest_api.ticketera_api.id
}
