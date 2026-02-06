# 🔐 Aquatiq Secrets & Credentials Setup Guide

This guide explains how to set up GitHub Secrets and credentials for the Aquatiq production deployment.

## Overview

Sensitive credentials are managed in **two locations**:

1. **GitHub Secrets** - Stored securely on GitHub (not in repository)
2. **VPS `/opt/aquatiq/secrets/`** - Generated during deployment from GitHub Secrets
3. **VPS `/opt/aquatiq/.env.production`** - Auto-generated environment file (not committed to git)

## ✅ Quick Setup (Interactive)

### 1. Install GitHub CLI

```bash
# macOS
brew install gh

# Linux / Windows WSL
curl -fsSL https://cli.github.com/install.sh | sudo bash

# Verify installation
gh --version
```

### 2. Authenticate with GitHub

```bash
gh auth login
# Follow prompts to authenticate
```

### 3. Run Setup Script

From the root of the repository:

```bash
chmod +x setup-github-secrets.sh
./setup-github-secrets.sh
```

The script will prompt you for all required credentials and automatically add them to GitHub Secrets.

## 📋 Credentials Reference

### Database & Cache (Required)

| Secret | Description | Example | Where Used |
|--------|-------------|---------|------------|
| `POSTGRES_PASSWORD` | PostgreSQL admin password | `super_secure_password_32_chars_min` | PostgreSQL container, pgAdmin connections |
| `REDIS_PASSWORD` | Redis authentication password | `redis_secure_password` | Redis, RedisInsight, cache |
| `NATS_AUTH_TOKEN` | NATS message queue token | `nats_auth_token` | NATS broker, internal services |
| `N8N_ENCRYPTION_KEY` | n8n encryption key (base64) | `base64_encoded_32_chars` | n8n workflow encryption |

### Application Configuration (Required)

| Secret | Description | Example |
|--------|-------------|---------|
| `DOMAIN` | Production domain | `aquatiq.com` |
| `INTEGRATION_GATEWAY_API_KEY` | Service-to-service auth key | `gateway_api_key_32_chars` |
| `OAUTH_ENCRYPTION_KEY` | OAuth2 system encryption (base64) | `base64_encoded_32_chars` |

### OAuth2 Integrations (Optional)

#### SuperOffice CRM
- **`SUPEROFFICE_CLIENT_ID`** - From https://community.superoffice.com/en/developer/create-apps/
- **`SUPEROFFICE_CLIENT_SECRET`** - OAuth2 client secret

#### Visma.net ERP
- **`VISMA_CLIENT_ID`** - From https://developer.visma.com/
- **`VISMA_CLIENT_SECRET`** - OAuth2 client secret

### Risk Agent Integration (Optional)

| Secret | Description |
|--------|-------------|
| `RISK_AGENT_URL` | Risk agent API endpoint (e.g., `http://31.97.38.31:8000/scan`) |
| `RISK_AGENT_API_KEY` | API key for risk agent authentication |

### Notifications (Optional)

| Secret | Description |
|--------|-------------|
| `TEAMS_TEAM_ID` | Microsoft Teams team ID for alerts |
| `TEAMS_CHANNEL_ID` | Microsoft Teams channel ID for alerts |
| `ALERT_EMAIL_TO` | Email address to receive alerts |
| `ALERT_EMAIL_FROM` | Email address alerts come from |

### Management UI Credentials (Optional)

| Secret | Description | Example |
|--------|-------------|---------|
| `PGADMIN_EMAIL` | pgAdmin login email | `admin@aquatiq.com` |
| `PGADMIN_PASSWORD` | pgAdmin login password | `secure_password` |
| `GRAFANA_PASSWORD` | Grafana admin password | `grafana_secure_password` |
| `TRAEFIK_DASHBOARD_AUTH` | Traefik dashboard basic auth (htpasswd format) | `$apr1$IYQ/eTz5$u31VvG2Ozfbp6oWFJklDV.` |

### Cloudflare Integration (Optional)

| Secret | Description |
|--------|-------------|
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token (needs DNS edit permission) |
| `CLOUDFLARE_ZONE_ID` | Cloudflare zone ID for your domain |

## 🔑 Generate Secure Credentials

Use these commands to generate secure credentials:

### Generate Base64-Encoded Keys

```bash
# OAuth encryption key (32 bytes base64)
openssl rand -base64 32

# N8N encryption key
openssl rand -base64 32

# Gateway API key
openssl rand -base64 32
```

### Generate Traefik Dashboard Auth

```bash
# Install htpasswd if needed:
# macOS: brew install httpd
# Linux: sudo apt-get install apache2-utils

# Generate basic auth hash (username: admin, password: your_password)
htpasswd -nb admin your_password

# Output will be something like:
# admin:$apr1$IYQ/eTz5$u31VvG2Ozfbp6oWFJklDV.
# Paste the entire line into TRAEFIK_DASHBOARD_AUTH
```

## 🚀 Automatic Deployment Flow

### 1. Push to `main` Branch

```bash
git add .
git commit -m "Feature: new integration"
git push origin main
```

### 2. GitHub Actions Triggers Automatically

1. **Build Job:**
   - Builds Docker image for aquatiq-gateway
   - Pushes to GitHub Container Registry (GHCR)

2. **Deploy Job:**
   - Clones latest code to VPS
   - Injects GitHub Secrets into VPS environment:
     - Creates `/opt/aquatiq/.env.production` with all secrets
     - Creates `/opt/aquatiq/secrets/*.txt` files
   - Pulls pre-built Docker images
   - Restarts Docker Compose services with updated configuration
   - Verifies health of all services

### 3. Services Auto-Update

All 13 services are updated with:
- Latest code
- Latest Docker images
- Latest credentials
- Updated configuration

## 🔍 Verify Deployment

After a push to `main`, check deployment status:

### On VPS via SSH

```bash
ssh root@31.97.38.31

# Check if .env.production was created
cat /opt/aquatiq/.env.production | head -20

# Verify secrets directory
ls -la /opt/aquatiq/secrets/

# Check container status
cd /opt/aquatiq && docker compose ps

# Check recent logs
docker compose logs -f aquatiq-gateway --tail 50
```

### On GitHub

1. Go to: https://github.com/I-Dacosta/Aquatiq-root/actions
2. Click on the latest workflow run
3. Check "Deploy to VPS" step for detailed logs

## ⚠️ Security Best Practices

### CRITICAL: Never Commit Credentials

```bash
# ❌ DON'T do this:
echo "POSTGRES_PASSWORD=my_password" > .env
git add .env
git commit -m "Add env vars"

# ✅ DO this instead:
# Use GitHub Secrets (setup-github-secrets.sh)
# Never commit .env, .env.production, or secrets/ directory
```

### Rotate Secrets Regularly

```bash
# 1. Generate new credential
openssl rand -base64 32

# 2. Update GitHub Secret
gh secret set SECRET_NAME --body "new_value"

# 3. Redeploy to VPS
git commit --allow-empty -m "Rotate secrets"
git push origin main
# Workflow automatically redeployed with new credentials
```

### Backup Secrets Securely

```bash
# Export secrets locally (NEVER commit these!)
gh secret list -L repo

# Save to encrypted backup
tar czf aquatiq-secrets-backup-$(date +%Y-%m-%d).tar.gz /opt/aquatiq/secrets/
# Store in secure location (encrypted drive, password manager, etc.)
```

## 🐛 Troubleshooting

### Workflow Failed - Permission Denied on VPS

**Problem:** SSH authentication failed

**Solution:**
```bash
# Verify VPS_SSH_KEY is configured correctly
gh secret list

# Re-add SSH key
gh secret set VPS_SSH_KEY < ~/.ssh/id_ed25519
```

### Services Won't Start - Missing Secrets

**Problem:** Containers failing to start after deployment

**Solution:**
```bash
# SSH into VPS
ssh root@31.97.38.31

# Check if secrets were created
ls -la /opt/aquatiq/secrets/

# Check docker compose logs
cd /opt/aquatiq
docker compose logs postgres | head -30
docker compose logs n8n | head -30

# If secrets missing, manually recreate:
mkdir -p /opt/aquatiq/secrets
echo "your_postgres_password" > /opt/aquatiq/secrets/postgres_password.txt
chmod 600 /opt/aquatiq/secrets/*.txt
docker compose up -d
```

### New Credentials Not Applied

**Problem:** Updated GitHub Secret but services still using old credential

**Solution:**
```bash
# Re-trigger deployment
git commit --allow-empty -m "Redeploy with updated credentials"
git push origin main

# OR manually force redeploy:
ssh root@31.97.38.31
cd /opt/aquatiq
docker compose down
docker compose up -d
```

## 📚 Related Documentation

- [Security Best Practices](../docs/SECURITY.md)
- [Deployment Guide](../docs/DOCUMENTATION_SUMMARY.md)
- [Environment Variables Reference](.env.example)
- [GitHub Actions Workflows](.github/workflows/build-and-deploy.yml)

## ❓ Questions?

Refer to:
1. `.env.example` - Documentation for each environment variable
2. `DEPLOYED_SERVICES_CREDENTIALS.txt` - Current production credential inventory
3. GitHub Actions logs - Real-time deployment details
4. VPS logs - Service startup and runtime logs
