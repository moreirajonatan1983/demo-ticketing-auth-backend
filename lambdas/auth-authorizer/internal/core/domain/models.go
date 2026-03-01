package domain

import (
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

var (
	ErrInvalidToken = errors.New("invalid or malicious token")
	ErrExpiredToken = errors.New("token has expired")
	ErrMissingAuth  = errors.New("missing authorization token")
)

type UserClaims struct {
	ID    string `json:"id"`
	Email string `json:"email"`
	Role  string `json:"role"`
	jwt.RegisteredClaims
}

type TokenResponse struct {
	Token     string    `json:"access_token"`
	ExpiresAt time.Time `json:"expires_at"`
}
