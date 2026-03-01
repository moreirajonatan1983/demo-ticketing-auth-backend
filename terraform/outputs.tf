output "api_gateway_id" {
  value = module.api_gateway.api_gateway_id
}
output "api_gateway_url" {
  value = "http://localhost:4566/restapis/${module.api_gateway.api_gateway_id}/dev/_user_request_"
}
