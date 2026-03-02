#!/usr/bin/env bash
# ============================================================
# SETUP ONE-TIME: Crear los secretos JWT en SSM Parameter Store
# Ejecutar UNA SOLA VEZ por ambiente, ANTES del primer terraform apply
#
# El valor del secreto debe ser una cadena larga y aleatoria.
# ============================================================

set -e

STAGE_ACCOUNT_ID="856521070960"
PROD_ACCOUNT_ID="470362823158"
REGION="us-east-1"

# ---- STAGE ----
echo "Creando JWT secret en cuenta auth-STAGE..."

JWT_SECRET_STAGE=$(openssl rand -hex 32)   # Genera 64 caracteres aleatorios

aws sts assume-role \
  --role-arn "arn:aws:iam::${STAGE_ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name "SetupSecrets" \
  --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
  --output text | read -r KEY SECRET TOKEN

AWS_ACCESS_KEY_ID=$KEY AWS_SECRET_ACCESS_KEY=$SECRET AWS_SESSION_TOKEN=$TOKEN \
aws ssm put-parameter \
  --name "/demo-ticketing/stage/auth/jwt_secret" \
  --value "$JWT_SECRET_STAGE" \
  --type "SecureString" \
  --region "$REGION" \
  --overwrite

echo "✅ JWT Secret STAGE guardado en SSM"

# ---- PROD ----
echo "Creando JWT secret en cuenta auth-PROD..."

JWT_SECRET_PROD=$(openssl rand -hex 32)   # Genera un secret DIFERENTE para PROD

aws sts assume-role \
  --role-arn "arn:aws:iam::${PROD_ACCOUNT_ID}:role/OrganizationAccountAccessRole" \
  --role-session-name "SetupSecrets" \
  --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
  --output text | read -r KEY SECRET TOKEN

AWS_ACCESS_KEY_ID=$KEY AWS_SECRET_ACCESS_KEY=$SECRET AWS_SESSION_TOKEN=$TOKEN \
aws ssm put-parameter \
  --name "/demo-ticketing/prod/auth/jwt_secret" \
  --value "$JWT_SECRET_PROD" \
  --type "SecureString" \
  --region "$REGION" \
  --overwrite

echo "✅ JWT Secret PROD guardado en SSM"
echo ""
echo "⚠️  Guardá estos valores en un lugar seguro (no en git):"
echo "STAGE JWT_SECRET: $JWT_SECRET_STAGE"
echo "PROD  JWT_SECRET: $JWT_SECRET_PROD"
