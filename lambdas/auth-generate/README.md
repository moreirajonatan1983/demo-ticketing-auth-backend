# Auth Generate Lambda

Lambda function used to generate Mock JWTs during local development to bypass Cognito. Written in Go under Hexagonal Architecture.

## Component Description
Takes an email and role dynamically via JSON POST request, builds the `UserClaims`, and signs them creating a valid JWT response suitable to be accepted by the `auth-authorizer`.

## Technologies Used
- AWS Lambda
- Go
- Hexagonal Architecture
