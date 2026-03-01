# Auth Authorizer Lambda

Acts as a Custom Authorizer for the robust API Gateway. Written in Go using Hexagonal Architecture.

## Component Description
This Lambda intercepts requests going into API Gateway endpoints, pulls out the `Authorization: Bearer <token>` header, parses it, validates its cryptographic signature (RS256 / HS256), and constructs the respective IAM Policy Document (Allow/Deny) back to API Gateway.

## Technologies Used
- AWS Lambda
- Go
- Hexagonal Architecture
- LocalStack
