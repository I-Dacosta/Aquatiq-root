#!/bin/bash
# Deploy SSL Configuration Fixes to VPS
# Run this script on your VPS to apply the SSL/TLS configuration updates

set -e

echo "=================================================="
echo "🔒 Deploying SSL Configuration Fixes"
echo "=================================================="
echo ""

# Check if running on VPS
if [ ! -d "/opt/aquatiq-root-container" ]; then
  echo "❌ Error: /opt/aquatiq-root-container not found"
  echo "   This script should be run on the VPS"
  exit 1
fi

cd /opt/aquatiq-root-container

echo "📥 Pulling latest changes from GitHub..."
git pull origin main || {
  echo "⚠️  Git pull failed, trying to reset..."
  git fetch origin main
  git reset --hard origin/main
}

echo ""
echo "🔍 Verifying SSL certificate files..."
if [ ! -f "cloudflare-certs/origin-cert.pem" ]; then
  echo "❌ Missing: cloudflare-certs/origin-cert.pem"
  exit 1
fi

if [ ! -f "cloudflare-certs/origin-key.pem" ]; then
  echo "❌ Missing: cloudflare-certs/origin-key.pem"
  exit 1
fi

echo "✅ SSL certificates found"
echo ""

echo "🐳 Restarting Traefik to apply new configuration..."
docker compose restart traefik

echo ""
echo "⏳ Waiting for Traefik to be healthy..."
sleep 5

# Check Traefik health
if docker ps | grep aquatiq-traefik | grep -q "healthy\|Up"; then
  echo "✅ Traefik is running"
else
  echo "⚠️  Traefik may not be healthy, checking logs..."
  docker logs aquatiq-traefik --tail=20
fi

echo ""
echo "🔄 Restarting affected services..."
docker compose restart n8n app aquatiq-gateway pgadmin redis-insight prometheus grafana

echo ""
echo "⏳ Waiting for services to stabilize..."
sleep 10

echo ""
echo "📊 Service Status:"
docker compose ps | grep -E "(traefik|n8n|app|gateway|pgadmin|redis|prometheus|grafana)" || docker compose ps

echo ""
echo "=================================================="
echo "✅ SSL Configuration Deployment Complete!"
echo "=================================================="
echo ""
echo "🧪 Test your services:"
echo "   • n8n:        https://n8n.aquatiq.com"
echo "   • app:        https://app.aquatiq.com"
echo "   • admin:      https://admin.aquatiq.com"
echo "   • pgadmin:    https://pgadmin.aquatiq.com"
echo "   • redis:      https://redis.aquatiq.com"
echo "   • prometheus: https://prometheus.aquatiq.com"
echo "   • grafana:    https://grafana.aquatiq.com"
echo "   • tools:      https://tools.aquatiq.com (after setup)"
echo ""
echo "📋 For tools.aquatiq.com setup, see: TOOLS_INTEGRATION.md"
echo ""
echo "🔍 Check Traefik logs if issues persist:"
echo "   docker logs aquatiq-traefik --tail=100 --follow"
echo ""
