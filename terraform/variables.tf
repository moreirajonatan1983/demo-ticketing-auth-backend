variable "environment" {
  type        = string
  description = "Ambiente de despliegue (stage o prod)"
}

variable "target_account_role_arn" {
  type        = string
  description = "El ARN del rol IAM a asumir para desplegar los recursos (ej: el OrganizationAccountAccessRole de la cuenta auth-stage o auth-prod)"
}
