package services

import (
	"context"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jonatandanielmoreira/demo-ticketing-auth-backend/internal/core/domain"
	"github.com/jonatandanielmoreira/demo-ticketing-auth-backend/internal/core/ports"
)

type authService struct {
	secretKey  []byte
	issuer     string
	expiration time.Duration
}

// NewAuthService creates a new authentication service that implements the AuthPolicyService port
func NewAuthService(secret string, issuer string, expHours int) ports.AuthPolicyService {
	return &authService{
		secretKey:  []byte(secret),
		issuer:     issuer,
		expiration: time.Duration(expHours) * time.Hour,
	}
}

func (s *authService) GenerateToken(ctx context.Context, userID, email, role string) (*domain.TokenResponse, error) {
	expirationTime := time.Now().Add(s.expiration)
	claims := &domain.UserClaims{
		ID:    userID,
		Email: email,
		Role:  role,
		RegisteredClaims: jwt.RegisteredClaims{
			ExpiresAt: jwt.NewNumericDate(expirationTime),
			Issuer:    s.issuer,
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	tokenString, err := token.SignedString(s.secretKey)
	if err != nil {
		return nil, err
	}

	return &domain.TokenResponse{
		Token:     tokenString,
		ExpiresAt: expirationTime,
	}, nil
}

func (s *authService) ValidateToken(ctx context.Context, tokenString string) (*domain.UserClaims, error) {
	claims := &domain.UserClaims{}

	token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
		// Validar que el algoritmo de firma sea HMAC
		if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, domain.ErrInvalidToken
		}
		return s.secretKey, nil
	})

	if err != nil {
		if errorsIs(err, jwt.ErrTokenExpired) {
			return nil, domain.ErrExpiredToken
		}
		return nil, domain.ErrInvalidToken
	}

	if !token.Valid {
		return nil, domain.ErrInvalidToken
	}

	return claims, nil
}

func errorsIs(err, target error) bool {
	// Simple helper since we don't import standard errors inside the specific handler check
	return err.Error() == target.Error()
}
