package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/jonatandanielmoreira/demo-ticketing-auth-backend/internal/adapters/handlers"
	"github.com/jonatandanielmoreira/demo-ticketing-auth-backend/internal/core/services"
)

func main() {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "default-demo-secret-key-for-localstack"
	}

	authSvc := services.NewAuthService(secret, "demo-ticketing-auth", 24)
	handler := handlers.NewAuthHandler(authSvc)

	// Since we compile one binary for both Token Generator and Token Authorizer using a single Go lambda,
	// We use an environment variable to decide WHICH handler to start.
	mode := os.Getenv("LAMBDA_HANDLER_MODE")

	switch mode {
	case "GENERATE_TOKEN":
		lambda.Start(handler.GenerateToken)
	case "AUTHORIZE":
		// En mode AUTHORIZER de API Gateway
		lambda.Start(handler.LambdaAuthorizer)
	default:
		lambda.Start(func(ctx context.Context, request interface{}) (interface{}, error) {
			b, _ := json.Marshal(request)
			fmt.Println("Generic Handler called with:", string(b))
			return events.APIGatewayProxyResponse{
				StatusCode: 400,
				Body:       `{"error": "LAMBDA_HANDLER_MODE not set"}`,
			}, nil
		})
	}
}
