package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	"github.com/aws/aws-lambda-go/events"
	"github.com/jonatandanielmoreira/demo-ticketing-auth-backend/internal/core/domain"
	"github.com/jonatandanielmoreira/demo-ticketing-auth-backend/internal/core/ports"
)

type AuthHandler struct {
	authService ports.AuthPolicyService
}

func NewAuthHandler(svc ports.AuthPolicyService) *AuthHandler {
	return &AuthHandler{
		authService: svc,
	}
}

// GenerateToken handles token creation for Demo Mock Login
func (h *AuthHandler) GenerateToken(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	// CORS Headers
	headers := map[string]string{
		"Access-Control-Allow-Origin":  "*",
		"Access-Control-Allow-Methods": "POST, OPTIONS",
		"Access-Control-Allow-Headers": "Content-Type",
	}

	if request.HTTPMethod == "OPTIONS" {
		return events.APIGatewayProxyResponse{StatusCode: 200, Headers: headers}, nil
	}

	var reqBody struct {
		Email string `json:"email"`
		Role  string `json:"role"`
	}

	if err := json.Unmarshal([]byte(request.Body), &reqBody); err != nil {
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusBadRequest,
			Headers:    headers,
			Body:       `{"error": "Invalid request payload"}`,
		}, nil
	}

	// For Demo purposes, generate dynamic mock ID
	mockID := "user-" + strings.Split(reqBody.Email, "@")[0]
	role := reqBody.Role
	if role == "" {
		role = "user"
	}

	tokenResp, err := h.authService.GenerateToken(ctx, mockID, reqBody.Email, role)
	if err != nil {
		return events.APIGatewayProxyResponse{
			StatusCode: http.StatusInternalServerError,
			Headers:    headers,
			Body:       `{"error": "Failed to generate token"}`,
		}, nil
	}

	body, _ := json.Marshal(tokenResp)
	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Headers:    headers,
		Body:       string(body),
	}, nil
}

// LambdaAuthorizer acts as an APIGateway Custom Authorizer (JWT Validations)
// For requests matching the "Authorization" header
func (h *AuthHandler) LambdaAuthorizer(ctx context.Context, request events.APIGatewayCustomAuthorizerRequest) (events.APIGatewayCustomAuthorizerResponse, error) {
	tokenString := strings.TrimPrefix(request.AuthorizationToken, "Bearer ")

	if tokenString == "" || tokenString == request.AuthorizationToken {
		return generatePolicy("user", "Deny", request.MethodArn), domain.ErrMissingAuth
	}

	claims, err := h.authService.ValidateToken(ctx, tokenString)
	if err != nil {
		return generatePolicy("unauthorized", "Deny", request.MethodArn), err
	}

	// Si es válido, devolvemos policy en Allow con el user ID principal
	return generatePolicy(claims.ID, "Allow", request.MethodArn), nil
}

func generatePolicy(principalID, effect, resource string) events.APIGatewayCustomAuthorizerResponse {
	// Generate an IAM Policy document
	authResponse := events.APIGatewayCustomAuthorizerResponse{PrincipalID: principalID}
	if effect != "" && resource != "" {
		policyDocument := events.APIGatewayCustomAuthorizerPolicy{
			Version: "2012-10-17",
			Statement: []events.IAMPolicyStatement{
				{
					Action:   []string{"execute-api:Invoke"},
					Effect:   effect,
					Resource: []string{resource},
				},
			},
		}
		authResponse.PolicyDocument = policyDocument
	}
	return authResponse
}
