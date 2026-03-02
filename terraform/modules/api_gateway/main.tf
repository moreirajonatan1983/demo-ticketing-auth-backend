resource "aws_api_gateway_rest_api" "auth_api" {
  name        = "demo-ticketing-auth-api-${var.environment}"
  description = "Auth API — genera y valida JWTs para la plataforma de ticketing"
}

# =====================================================================
# Request Validator — Valida que el header Authorization esté presente
# Reemplaza WAF sin costo adicional
# =====================================================================
resource "aws_api_gateway_request_validator" "validate_headers" {
  name                        = "ValidateAuthorizationHeader"
  rest_api_id                 = aws_api_gateway_rest_api.auth_api.id
  validate_request_body       = false
  validate_request_parameters = true
}

# =====================================================================
# Lambda Authorizer (JWT Validator)
# =====================================================================
resource "aws_api_gateway_authorizer" "jwt_auth" {
  name                   = "demo_jwt_authorizer_${var.environment}"
  rest_api_id            = aws_api_gateway_rest_api.auth_api.id
  authorizer_uri         = var.auth_lambda_invoke_arn
  authorizer_credentials = var.auth_role_arn
  type                   = "TOKEN"
  identity_source        = "method.request.header.Authorization"
}

# ===================== POST /auth — Genera el JWT =====================
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.auth_api.id
  parent_id   = aws_api_gateway_rest_api.auth_api.root_resource_id
  path_part   = "auth"
}

resource "aws_api_gateway_method" "auth_post" {
  rest_api_id   = aws_api_gateway_rest_api.auth_api.id
  resource_id   = aws_api_gateway_resource.auth.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "auth_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.auth_api.id
  resource_id             = aws_api_gateway_resource.auth.id
  http_method             = aws_api_gateway_method.auth_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.generate_lambda_invoke_arn
}

# =====================================================================
# Permiso: API Gateway puede invocar la Lambda Auth Generate
# =====================================================================
resource "aws_lambda_permission" "apigw_invoke_generate" {
  statement_id  = "AllowAPIGatewayInvokeGenerate"
  action        = "lambda:InvokeFunction"
  function_name = var.generate_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.auth_api.execution_arn}/*/*"
}

# =====================================================================
# Permiso: API Gateway puede invocar la Lambda Authorizer
# =====================================================================
resource "aws_lambda_permission" "apigw_invoke_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = var.auth_lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.auth_api.execution_arn}/*/*"
}

# =====================================================================
# Deployment
# =====================================================================
resource "aws_api_gateway_deployment" "auth_deploy" {
  rest_api_id = aws_api_gateway_rest_api.auth_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.auth.id,
      aws_api_gateway_method.auth_post.id,
      aws_api_gateway_integration.auth_lambda.id,
      aws_api_gateway_request_validator.validate_headers.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.auth_lambda
  ]
}

resource "aws_api_gateway_stage" "auth_stage" {
  deployment_id = aws_api_gateway_deployment.auth_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.auth_api.id
  stage_name    = var.environment

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_logs.arn
  }
}

# CloudWatch Logs del API Gateway (auditoría gratuita)
resource "aws_cloudwatch_log_group" "apigw_logs" {
  name              = "/aws/apigateway/demo-ticketing-auth-${var.environment}"
  retention_in_days = 7  # Mínimo para Free Tier
}

# =====================================================================
# Usage Plan — Throttling (reemplaza WAF Rate Limiting, sin costo)
# burst_limit = 10 → pico máximo de requests simultáneos permitidos
# rate_limit  =  5 → requests por segundo sostenidos
# =====================================================================
resource "aws_api_gateway_usage_plan" "auth_plan" {
  name        = "demo-ticketing-auth-plan-${var.environment}"
  description = "Throttling nativo: burst=10, rate=5 req/s — protección sin WAF"

  api_stages {
    api_id = aws_api_gateway_rest_api.auth_api.id
    stage  = aws_api_gateway_stage.auth_stage.stage_name
  }

  throttle_settings {
    burst_limit = 10
    rate_limit  = 5
  }
}
