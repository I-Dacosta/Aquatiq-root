#!/usr/bin/env bash
# reset-local.sh
# Stops and resets the Aquatiq Root Container for local development
# Deletes all containers, volumes and networks defined in docker-compose.local.yml

set -euo pipefail

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.local.yml}"
ENV_FILE="${ENV_FILE:-.env.local}"

echo "⚠️ WARNING: This operation will:"
echo "  - stop all Aquatiq containers used for local development"
echo "  - delete related Docker volumes (data for Postgres, Redis, n8n, MinIO, Qdrant, etc.)"
echo "  - delete the 'aquatiq-local' and 'ima-local' networks if they are not used by others"
echo
read -r -p "Type 'yes' to confirm a full reset of the local stack: " ANSWER

if [ "$ANSWER" != "yes" ]; then
  echo "❌ Aborted. No changes were made."
  exit 0
fi

# Check that docker is available
if ! command -v docker &> /dev/null; then
  echo "❌ docker is not installed or not in PATH."
  exit 1
fi

# Check that compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
  echo "❌ Could not find $COMPOSE_FILE in this directory."
  echo "   Run this script from the project root."
  exit 1
fi

echo
echo "🛑 Stopping and removing containers, volumes and orphans..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down --volumes --remove-orphans || true

echo
echo "🧹 Cleaning up specific Aquatiq volumes (if they still exist)..."

VOLUMES=(
  "postgres_local_data"
  "redis_local_data"
  "nats_local_data"
  "qdrant-data"
  "n8n_local_data"
  "pgadmin_local_data"
  "redis_insight_local_data"
  "aquatiq_gateway_local_data"
  "minio-data"
)

for vol in "${VOLUMES[@]}"; do
  if docker volume ls --format "{{.Name}}" | grep -q "^${vol}$"; then
    echo "  - Removing volume: ${vol}"
    docker volume rm "${vol}" >/dev/null 2>&1 || true
  fi
done

echo
echo "🌐 Cleaning up networks (if they are not used by other containers)..."

NETWORKS=(
  "aquatiq-local"
  "ima-local"
)

for net in "${NETWORKS[@]}"; do
  if docker network ls --format "{{.Name}}" | grep -q "^${net}$"; then
    echo "  - Attempting to remove network: ${net}"
    docker network rm "${net}" >/dev/null 2>&1 || true
  fi
done

echo
echo "✅ Local Aquatiq Root Container stack has been reset."
echo
echo "To start again with the local dev configuration:"
echo "  ./start-local.sh"
