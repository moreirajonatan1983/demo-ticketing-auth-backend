resource "aws_api_gateway_rest_api" "ticketera_api" {
  name        = "TicketeraAPI"
  description = "Centralized API Gateway with Custom Authorizer"
}

resource "aws_api_gateway_authorizer" "jwt_auth" {
  name                   = "demo_jwt_authorizer"
  rest_api_id            = aws_api_gateway_rest_api.ticketera_api.id
  authorizer_uri         = aws_lambda_function.auth_authorizer.invoke_arn
  authorizer_credentials = aws_iam_role.iam_for_lambda.arn
  type                   = "TOKEN"
}

# Proxy resource Catch-All (Since SAM Local runs locally on the host)
# We will just route /events/* -> port 3000, /shows/* -> port 3007
# But doing path-based routing in API Gateway requires explicit resources.

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
  uri                     = aws_lambda_function.auth_generate.invoke_arn
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
  authorization = "NONE" # Public
}
resource "aws_api_gateway_integration" "events_get_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.ticketera_api.id
  resource_id             = aws_api_gateway_resource.events.id
  http_method             = aws_api_gateway_method.events_get.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "http://host.docker.internal:3000/events"
  passthrough_behavior    = "WHEN_NO_MATCH"
}

# ===================== /events/{proxy+} =====================
resource "aws_api_gateway_resource" "events_proxy" {
  rest_api_id = aws_api_gateway_rest_api.ticketera_api.id
  parent_id   = aws_api_gateway_resource.events.id
  path_part   = "{proxy+}"
}
resource "aws_api_gateway_method" "events_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.ticketera_api.id
  resource_id   = aws_api_gateway_resource.events_proxy.id
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.proxy" = true
  }
}
resource "aws_api_gateway_integration" "events_proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.ticketera_api.id
  resource_id             = aws_api_gateway_resource.events_proxy.id
  http_method             = aws_api_gateway_method.events_proxy_any.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://host.docker.internal:3000/events/{proxy}"
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# ===================== /tickets =====================
resource "aws_api_gateway_resource" "tickets" {
  rest_api_id = aws_api_gateway_rest_api.ticketera_api.id
  parent_id   = aws_api_gateway_rest_api.ticketera_api.root_resource_id
  path_part   = "tickets"
}
# /tickets/{proxy+}
resource "aws_api_gateway_resource" "tickets_proxy" {
  rest_api_id = aws_api_gateway_rest_api.ticketera_api.id
  parent_id   = aws_api_gateway_resource.tickets.id
  path_part   = "{proxy+}"
}
resource "aws_api_gateway_method" "tickets_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.ticketera_api.id
  resource_id   = aws_api_gateway_resource.tickets_proxy.id
  http_method   = "ANY"
  authorization = "CUSTOM"
  authorizer_id = aws_api_gateway_authorizer.jwt_auth.id
  request_parameters = {
    "method.request.path.proxy" = true
  }
}
resource "aws_api_gateway_integration" "tickets_proxy_integration" {
  rest_api_id             = aws_api_gateway_rest_api.ticketera_api.id
  resource_id             = aws_api_gateway_resource.tickets_proxy.id
  http_method             = aws_api_gateway_method.tickets_proxy_any.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://host.docker.internal:3006/tickets/{proxy}"
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
}

# Deploy the API
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
      aws_api_gateway_integration.auth_lambda.id
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
  stage_name    = "dev"
}
