resource "aws_api_gateway_rest_api" "ticketera_api" {
  name        = "TicketeraAPI"
  description = "Centralized API Gateway with Custom Authorizer"
}

resource "aws_api_gateway_authorizer" "jwt_auth" {
  name                   = "demo_jwt_authorizer"
  rest_api_id            = aws_api_gateway_rest_api.ticketera_api.id
  authorizer_uri         = var.auth_lambda_invoke_arn
  authorizer_credentials = var.auth_role_arn
  type                   = "TOKEN"
}

# =====================================================================
# Request Validator — Valida que el header Authorization esté presente
# Reemplaza la función de WAF de validación de requests sin costo extra
# =====================================================================
resource "aws_api_gateway_request_validator" "validate_headers" {
  name                        = "ValidateRequestHeaders"
  rest_api_id                 = aws_api_gateway_rest_api.ticketera_api.id
  validate_request_body       = false
  validate_request_parameters = true
}

# ===================== /auth =====================
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.ticketera_api.id
  parent_id   = aws_api_gateway_rest_api.ticketera_api.root_resource_id
  path_part   = "auth"
}
resource "aws_api_gateway_method" "auth_post" {
  rest_api_id   = aws_api_gateway_rest_api.ticketera_api.id
  resource_id   = aws_api_gateway_resource.auth.id
  http_method   = "POST"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "auth_lambda" {
  rest_api_id             = aws_api_gateway_rest_api.ticketera_api.id
  resource_id             = aws_api_gateway_resource.auth.id
  http_method             = aws_api_gateway_method.auth_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.generate_lambda_invoke_arn
}

# ===================== /events =====================
resource "aws_api_gateway_resource" "events" {
  rest_api_id = aws_api_gateway_rest_api.ticketera_api.id
  parent_id   = aws_api_gateway_rest_api.ticketera_api.root_resource_id
  path_part   = "events"
}
resource "aws_api_gateway_method" "events_get" {
  rest_api_id   = aws_api_gateway_rest_api.ticketera_api.id
  resource_id   = aws_api_gateway_resource.events.id
  http_method   = "GET"
  authorization = "NONE"
}
resource "aws_api_gateway_integration" "events_get_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.ticketera_api.id
  resource_id             = aws_api_gateway_resource.events.id
  http_method             = aws_api_gateway_method.events_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.events_lambda_invoke_arn
}

# ===================== /events/{proxy+} =====================
resource "aws_api_gateway_resource" "events_proxy" {
  rest_api_id = aws_api_gateway_rest_api.ticketera_api.id
  parent_id   = aws_api_gateway_resource.events.id
  path_part   = "{proxy+}"
}
resource "aws_api_gateway_method" "events_proxy_any" {
  rest_api_id          = aws_api_gateway_rest_api.ticketera_api.id
  resource_id          = aws_api_gateway_resource.events_proxy.id
  http_method          = "ANY"
  authorization        = "CUSTOM"
  authorizer_id        = aws_api_gateway_authorizer.jwt_auth.id
  request_validator_id = aws_api_gateway_request_validator.validate_headers.id
  request_parameters = {
    "method.request.path.proxy"           = true
    "method.request.header.Authorization" = true
  }
}
resource "aws_api_gateway_integration" "events_proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.ticketera_api.id
  resource_id             = aws_api_gateway_resource.events_proxy.id
  http_method             = aws_api_gateway_method.events_proxy_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.events_lambda_invoke_arn
}

# ===================== /tickets =====================
resource "aws_api_gateway_resource" "tickets" {
  rest_api_id = aws_api_gateway_rest_api.ticketera_api.id
  parent_id   = aws_api_gateway_rest_api.ticketera_api.root_resource_id
  path_part   = "tickets"
}
resource "aws_api_gateway_resource" "tickets_proxy" {
  rest_api_id = aws_api_gateway_rest_api.ticketera_api.id
  parent_id   = aws_api_gateway_resource.tickets.id
  path_part   = "{proxy+}"
}
resource "aws_api_gateway_method" "tickets_proxy_any" {
  rest_api_id          = aws_api_gateway_rest_api.ticketera_api.id
  resource_id          = aws_api_gateway_resource.tickets_proxy.id
  http_method          = "ANY"
  authorization        = "CUSTOM"
  authorizer_id        = aws_api_gateway_authorizer.jwt_auth.id
  request_validator_id = aws_api_gateway_request_validator.validate_headers.id
  request_parameters = {
    "method.request.path.proxy"           = true
    "method.request.header.Authorization" = true
  }
}
resource "aws_api_gateway_integration" "tickets_proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.ticketera_api.id
  resource_id             = aws_api_gateway_resource.tickets_proxy.id
  http_method             = aws_api_gateway_method.tickets_proxy_any.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.tickets_lambda_invoke_arn
}

# =====================================================================
# Deploy
# =====================================================================
resource "aws_api_gateway_deployment" "ticketera_deploy" {
  rest_api_id = aws_api_gateway_rest_api.ticketera_api.id
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.events.id,
      aws_api_gateway_method.events_get.id,
      aws_api_gateway_integration.events_get_proxy.id,
      aws_api_gateway_resource.tickets.id,
      aws_api_gateway_method.tickets_proxy_any.id,
      aws_api_gateway_integration.tickets_proxy_integration.id,
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
    aws_api_gateway_integration.events_get_proxy,
    aws_api_gateway_integration.events_proxy_integration,
    aws_api_gateway_integration.tickets_proxy_integration,
    aws_api_gateway_integration.auth_lambda
  ]
}

resource "aws_api_gateway_stage" "ticketera_stage" {
  deployment_id = aws_api_gateway_deployment.ticketera_deploy.id
  rest_api_id   = aws_api_gateway_rest_api.ticketera_api.id
  stage_name    = var.environment
}

# =====================================================================
# Usage Plan con Throttling — Reemplaza WAF Rate Limiting (sin costo)
# burst_limit = 10 → pico máximo de requests simultáneos
# rate_limit   = 5  → requests por segundo sostenidos
# =====================================================================
resource "aws_api_gateway_usage_plan" "ticketera_plan" {
  name        = "demo-ticketing-usage-plan-${var.environment}"
  description = "Throttling nativo. Reemplaza WAF: burst=10 req simultáneos, rate=5 req/s"

  api_stages {
    api_id = aws_api_gateway_rest_api.ticketera_api.id
    stage  = aws_api_gateway_stage.ticketera_stage.stage_name
  }

  throttle_settings {
    burst_limit = 10   # Máximo de requests concurrentes permitidos (protección contra spikes)
    rate_limit  = 5    # Requests por segundo sostenidos permitidos
  }
}
