#!/bin/bash
# Setup GitHub Secrets for Aquatiq Production Deployment
# Run this script to add all sensitive credentials to GitHub Secrets
# Prerequisites: gh CLI installed and authenticated (gh auth login)

set -e

echo "🔐 Setting up GitHub Secrets for Aquatiq..."
echo "==========================================="
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ ERROR: GitHub CLI (gh) is not installed."
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Get current repository
REPO=$(git config --get remote.origin.url | sed 's/.*:\|.git//g')
if [ -z "$REPO" ]; then
    echo "❌ ERROR: Could not determine repository. Make sure you're in a git repository."
    exit 1
fi

echo "📦 Repository: $REPO"
echo ""

# Database & Cache Credentials (from local development - UPDATE FOR PRODUCTION!)
read -sp "PostgreSQL Password: " POSTGRES_PASSWORD
echo ""
read -sp "Redis Password: " REDIS_PASSWORD
echo ""
read -sp "NATS Auth Token: " NATS_AUTH_TOKEN
echo ""
read -sp "N8N Encryption Key: " N8N_ENCRYPTION_KEY
echo ""

# Application Settings
read -p "Domain (e.g., aquatiq.com): " DOMAIN
read -sp "Integration Gateway API Key: " INTEGRATION_GATEWAY_API_KEY
echo ""
read -sp "OAuth2 Encryption Key: " OAUTH_ENCRYPTION_KEY
echo ""

# SuperOffice Integration
read -p "SuperOffice Client ID: " SUPEROFFICE_CLIENT_ID
read -sp "SuperOffice Client Secret: " SUPEROFFICE_CLIENT_SECRET
echo ""

# Visma Integration
read -p "Visma Client ID: " VISMA_CLIENT_ID
read -sp "Visma Client Secret: " VISMA_CLIENT_SECRET
echo ""

# Risk Agent Integration
read -p "Risk Agent URL: " RISK_AGENT_URL
read -sp "Risk Agent API Key: " RISK_AGENT_API_KEY
echo ""

# Notifications
read -p "Teams Team ID (optional): " TEAMS_TEAM_ID
read -p "Teams Channel ID (optional): " TEAMS_CHANNEL_ID
read -p "Alert Email To: " ALERT_EMAIL_TO
read -p "Alert Email From: " ALERT_EMAIL_FROM

# Management UI Credentials
read -p "pgAdmin Email: " PGADMIN_EMAIL
read -sp "pgAdmin Password: " PGADMIN_PASSWORD
echo ""
read -sp "Grafana Admin Password: " GRAFANA_PASSWORD
echo ""
read -sp "Traefik Dashboard Auth (htpasswd): " TRAEFIK_DASHBOARD_AUTH
echo ""

# Cloudflare
read -p "Cloudflare API Token: " CLOUDFLARE_API_TOKEN
read -p "Cloudflare Zone ID: " CLOUDFLARE_ZONE_ID

echo ""
echo "✅ Validating inputs..."

# Validate required fields
REQUIRED_FIELDS=("POSTGRES_PASSWORD" "REDIS_PASSWORD" "NATS_AUTH_TOKEN" "N8N_ENCRYPTION_KEY" "DOMAIN" "INTEGRATION_GATEWAY_API_KEY" "OAUTH_ENCRYPTION_KEY")
for field in "${REQUIRED_FIELDS[@]}"; do
    if [ -z "${!field}" ]; then
        echo "❌ ERROR: $field is required"
        exit 1
    fi
done

echo "✅ All required fields provided"
echo ""
echo "🚀 Adding secrets to GitHub..."
echo ""

# Add secrets to GitHub
gh secret set POSTGRES_PASSWORD --body "$POSTGRES_PASSWORD" --repo "$REPO"
gh secret set REDIS_PASSWORD --body "$REDIS_PASSWORD" --repo "$REPO"
gh secret set NATS_AUTH_TOKEN --body "$NATS_AUTH_TOKEN" --repo "$REPO"
gh secret set N8N_ENCRYPTION_KEY --body "$N8N_ENCRYPTION_KEY" --repo "$REPO"
gh secret set DOMAIN --body "$DOMAIN" --repo "$REPO"
gh secret set INTEGRATION_GATEWAY_API_KEY --body "$INTEGRATION_GATEWAY_API_KEY" --repo "$REPO"
gh secret set OAUTH_ENCRYPTION_KEY --body "$OAUTH_ENCRYPTION_KEY" --repo "$REPO"
gh secret set SUPEROFFICE_CLIENT_ID --body "$SUPEROFFICE_CLIENT_ID" --repo "$REPO"
gh secret set SUPEROFFICE_CLIENT_SECRET --body "$SUPEROFFICE_CLIENT_SECRET" --repo "$REPO"
gh secret set VISMA_CLIENT_ID --body "$VISMA_CLIENT_ID" --repo "$REPO"
gh secret set VISMA_CLIENT_SECRET --body "$VISMA_CLIENT_SECRET" --repo "$REPO"
gh secret set RISK_AGENT_URL --body "$RISK_AGENT_URL" --repo "$REPO"
gh secret set RISK_AGENT_API_KEY --body "$RISK_AGENT_API_KEY" --repo "$REPO"
gh secret set TEAMS_TEAM_ID --body "$TEAMS_TEAM_ID" --repo "$REPO"
gh secret set TEAMS_CHANNEL_ID --body "$TEAMS_CHANNEL_ID" --repo "$REPO"
gh secret set ALERT_EMAIL_TO --body "$ALERT_EMAIL_TO" --repo "$REPO"
gh secret set ALERT_EMAIL_FROM --body "$ALERT_EMAIL_FROM" --repo "$REPO"
gh secret set PGADMIN_EMAIL --body "$PGADMIN_EMAIL" --repo "$REPO"
gh secret set PGADMIN_PASSWORD --body "$PGADMIN_PASSWORD" --repo "$REPO"
gh secret set GRAFANA_PASSWORD --body "$GRAFANA_PASSWORD" --repo "$REPO"
gh secret set TRAEFIK_DASHBOARD_AUTH --body "$TRAEFIK_DASHBOARD_AUTH" --repo "$REPO"
gh secret set CLOUDFLARE_API_TOKEN --body "$CLOUDFLARE_API_TOKEN" --repo "$REPO"
gh secret set CLOUDFLARE_ZONE_ID --body "$CLOUDFLARE_ZONE_ID" --repo "$REPO"

echo ""
echo "✅ All secrets added to GitHub!"
echo ""
echo "📋 Secrets created:"
echo "   ✓ POSTGRES_PASSWORD"
echo "   ✓ REDIS_PASSWORD"
echo "   ✓ NATS_AUTH_TOKEN"
echo "   ✓ N8N_ENCRYPTION_KEY"
echo "   ✓ DOMAIN"
echo "   ✓ INTEGRATION_GATEWAY_API_KEY"
echo "   ✓ OAUTH_ENCRYPTION_KEY"
echo "   ✓ SUPEROFFICE_CLIENT_ID"
echo "   ✓ SUPEROFFICE_CLIENT_SECRET"
echo "   ✓ VISMA_CLIENT_ID"
echo "   ✓ VISMA_CLIENT_SECRET"
echo "   ✓ RISK_AGENT_URL"
echo "   ✓ RISK_AGENT_API_KEY"
echo "   ✓ TEAMS_TEAM_ID"
echo "   ✓ TEAMS_CHANNEL_ID"
echo "   ✓ ALERT_EMAIL_TO"
echo "   ✓ ALERT_EMAIL_FROM"
echo "   ✓ PGADMIN_EMAIL"
echo "   ✓ PGADMIN_PASSWORD"
echo "   ✓ GRAFANA_PASSWORD"
echo "   ✓ TRAEFIK_DASHBOARD_AUTH"
echo "   ✓ CLOUDFLARE_API_TOKEN"
echo "   ✓ CLOUDFLARE_ZONE_ID"
echo ""
echo "Next: Update your GitHub Actions workflow to use these secrets!"
