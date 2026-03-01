variable "function_name" { type = string }
variable "role_arn" { type = string }
variable "handler" { type = string }
variable "archive_path" { type = string }
variable "source_code_hash" { type = string }
variable "env_vars" { type = map(string) }

output "invoke_arn" {
  value = aws_lambda_function.this.invoke_arn
}
