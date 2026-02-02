#!/usr/bin/env bash
# start-local.sh
# Starts the Aquatiq Root Container System for local development

set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.local.yml}"
ENV_FILE="${ENV_FILE:-.env.local}"

echo "🔧 Starting Aquatiq Root Container – local development"
echo

# Check that docker is available
if ! command -v docker &> /dev/null; then
  echo "❌ docker is not installed or not in PATH."
  echo "   Install Docker Desktop or Docker Engine before continuing."
  exit 1
fi

# Check that docker compose (v2) is available
if ! docker compose version &> /dev/null; then
  echo "❌ 'docker compose' is not available."
  echo "   Make sure you're using Docker Desktop with Compose v2."
  exit 1
fi

# Check that compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
  echo "❌ Could not find $COMPOSE_FILE in this directory."
  echo "   Run this script from the project root where $COMPOSE_FILE is located."
  exit 1
fi

# Create .env.local with default values if it doesn't exist
if [ ! -f "$ENV_FILE" ]; then
  echo "ℹ️ $ENV_FILE not found – creating default local dev configuration."
  cat > "$ENV_FILE" <<EOF
# Aquatiq Local Development Environment
# For local development only - simple default passwords

# ==============================================
# DATABASE CREDENTIALS
# ==============================================
POSTGRES_PASSWORD=postgres
REDIS_PASSWORD=redis
NATS_AUTH_TOKEN=nats

# ==============================================
# AQUATIQ GATEWAY
# ==============================================
INTEGRATION_GATEWAY_API_KEY=gateway
DOMAIN=localhost

# ==============================================
# N8N CONFIGURATION
# ==============================================
N8N_ENCRYPTION_KEY=n8n_encryption_key

# Timezone
GENERIC_TIMEZONE=Europe/Oslo
EOF
  echo "✅ Created $ENV_FILE with default values for local development."
  echo
else
  echo "✅ Found existing $ENV_FILE – using this for the local stack."
  echo
fi

echo "🚀 Starting containers with:"
echo "   - compose file: $COMPOSE_FILE"
echo "   - env file:     $ENV_FILE"
echo

docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d

echo
echo "✅ Aquatiq Root Container is up."
echo
echo "Available services locally (via localhost):"
echo "  - PostgreSQL:         127.0.0.1:5432"
echo "  - Redis:              127.0.0.1:6379"
echo "  - NATS:               127.0.0.1:4222 (monitor: 8222)"
echo "  - Qdrant (vector DB): 127.0.0.1:6333 (HTTP), 127.0.0.1:6334 (gRPC)"
echo "  - n8n:                http://127.0.0.1:5678"
echo "  - pgAdmin:            http://127.0.0.1:5050"
echo "  - RedisInsight:       http://127.0.0.1:5540"
echo "  - MinIO S3 API:       http://127.0.0.1:9010"
echo "  - MinIO Console:      http://127.0.0.1:9011"
echo "  - Aquatiq Gateway:    http://127.0.0.1:7500/health"
echo
echo "Active Aquatiq containers:"
docker ps --filter "name=aquatiq-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo
echo "ℹ️ To stop the stack:"
echo "   docker compose -f $COMPOSE_FILE down"
