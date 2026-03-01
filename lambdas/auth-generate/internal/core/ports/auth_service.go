package ports

import (
	"context"

	"github.com/jonatandanielmoreira/demo-ticketing-auth-backend/internal/core/domain"
)

// AuthPolicyService define the core business logic for generating and validating tokens
type AuthPolicyService interface {
	GenerateToken(ctx context.Context, userID, email, role string) (*domain.TokenResponse, error)
	ValidateToken(ctx context.Context, tokenString string) (*domain.UserClaims, error)
}
