output "api_gateway_id" {
  value = aws_api_gateway_rest_api.ticketera_api.id
}
output "api_gateway_url" {
  value = "http://localhost:4566/restapis/${aws_api_gateway_rest_api.ticketera_api.id}/dev/_user_request_"
}
