# Ticketera Cloud - Auth & Security

Este dominio centraliza la gestión de Identidad, Control de Acceso y Seguridad Perimetral para la plataforma Ticketera.

## Componentes y Responsabilidades
*   **Amazon Cognito**: Pooles de usuarios para la autenticación de clientes y administradores productoras de eventos.
*   **Gestión de JWTs**: Integración para el control de la API en el Core usando OAuth2 y OpenID Connect.
*   **SecOps & Políticas (IAM)**: Roles transversales seguros que asumen los microservicios en `core`.
*   **Protecciones Perimetrales (AWS WAF)**: Reglas básicas de mitigación (Bot Control, Rate Limiting) para resguardar la entrada al ecosistema ante picos fraudulentos de compra de tickets.

Este repositorio debe ser el primero en desplegarse debido a sus dependencias estrictas hacia el resto del ecosistema (OIDC Tokens).
