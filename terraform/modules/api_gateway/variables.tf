variable "auth_lambda_invoke_arn" { type = string }
variable "auth_role_arn" { type = string }
variable "generate_lambda_invoke_arn" { type = string }
variable "events_lambda_invoke_arn" { type = string }
variable "tickets_lambda_invoke_arn" { type = string }
variable "environment" { type = string }

output "api_gateway_id" {
  value = aws_api_gateway_rest_api.ticketera_api.id
}

output "api_gateway_url" {
  value = aws_api_gateway_stage.ticketera_stage.invoke_url
}
