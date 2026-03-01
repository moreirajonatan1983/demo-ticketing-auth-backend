variable "role_name" {
  type        = string
  description = "Name of the IAM Role"
}

output "role_arn" {
  value = aws_iam_role.iam_for_lambda.arn
}
