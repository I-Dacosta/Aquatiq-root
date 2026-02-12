# Contract Manager Subdomain Setup Guide

## Overview
Configure `contract.aquatiq.com` to route through Traefik in `/opt/aquatiq/aquatiq-root-container` to your Django Contract Manager at `/opt/aquatiq-contract-manager`.

## Prerequisites
- Traefik running in `/opt/aquatiq/aquatiq-root-container`
- Contract Manager container in `/opt/aquatiq-contract-manager`
- Both connected to `aquatiq_default` or `internal` network
- Cloudflare DNS configured

---

## Step 1: Configure Cloudflare DNS

1. Log in to Cloudflare dashboard
2. Select domain: `aquatiq.com`
3. Add DNS record:
   - **Type**: `A`
   - **Name**: `contract`
   - **IPv4 address**: `31.97.38.31` (your VPS IP)
   - **Proxy status**: ✅ Proxied (orange cloud)
   - **TTL**: Auto

---

## Step 2: Add Traefik Labels to Contract Manager

Edit `/opt/aquatiq-contract-manager/docker-compose.yml`:

```yaml
services:
  contract-manager:
    image: your-contract-manager-image:latest
    container_name: aquatiq-contract-manager
    restart: unless-stopped
    
    # ... your existing environment, volumes, etc. ...
    
    networks:
      - aquatiq_default  # Must match Traefik's network
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8001/admin/login/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    
    labels:
      # Enable Traefik routing
      - "traefik.enable=true"
      
      # HTTPS router
      - "traefik.http.routers.contract-manager.rule=Host(`contract.aquatiq.com`)"
      - "traefik.http.routers.contract-manager.entrypoints=websecure"
      - "traefik.http.routers.contract-manager.tls=true"
      - "traefik.http.services.contract-manager.loadbalancer.server.port=8001"
      
      # HTTP to HTTPS redirect
      - "traefik.http.routers.contract-manager-http.rule=Host(`contract.aquatiq.com`)"
      - "traefik.http.routers.contract-manager-http.entrypoints=web"
      - "traefik.http.routers.contract-manager-http.middlewares=redirect-to-https@file"
      
      # Specify which network Traefik should use
      - "traefik.docker.network=aquatiq_default"

networks:
  aquatiq_default:
    external: true
    name: aquatiq_default
```

> **Note**: If your Traefik is on the `internal` network, change `aquatiq_default` to `internal`.

> **Note**: Adjust the port (`8001`) if your Django app runs on a different port.

---

## Step 3: Verify Network Connectivity

Check that both containers share a network:

```bash
# List Traefik networks
docker inspect aquatiq-traefik | grep -A 10 Networks

# List Contract Manager networks
docker inspect aquatiq-contract-manager | grep -A 10 Networks
```

If they don't share a network, connect Contract Manager:

```bash
# Connect to internal network (if that's where Traefik is)
docker network connect internal aquatiq-contract-manager

# Or connect to aquatiq_default
docker network connect aquatiq_default aquatiq-contract-manager
```

---

## Step 4: Deploy Configuration

```bash
# SSH to VPS
ssh root@31.97.38.31

# Navigate to Contract Manager directory
cd /opt/aquatiq-contract-manager

# Restart with new labels
docker compose down
docker compose up -d

# Verify container is running and healthy
docker ps | grep contract-manager
```

Traefik will automatically detect the new labels within 30 seconds.

---

## Step 5: Verify Deployment

### Check Traefik Detection

```bash
docker logs aquatiq-traefik | grep contract-manager
```

Expected output:
```
level=info msg="Creating Router contract-manager@docker"
level=info msg="Creating Service contract-manager@docker"
```

### Test Access

```bash
# From VPS
curl -I http://localhost:8001/admin/login/

# From external (after DNS propagation)
curl -I https://contract.aquatiq.com
```

### Browser Test

Open: `https://contract.aquatiq.com`

You should see the Django Contract Manager login page with valid SSL.

---

## Troubleshooting

### Issue: 502 Bad Gateway

**Check container status:**
```bash
docker ps | grep contract-manager
docker logs aquatiq-contract-manager
```

**Check health status:**
```bash
docker inspect aquatiq-contract-manager | grep -A 10 Health
```

**Test health check manually:**
```bash
docker exec aquatiq-contract-manager curl -f http://localhost:8001/admin/login/
```

**Check network connectivity:**
```bash
docker network inspect internal | grep -A 5 contract
docker exec aquatiq-traefik ping aquatiq-contract-manager
```

### Issue: DNS Not Resolving

**Wait for propagation:**
```bash
dig contract.aquatiq.com
nslookup contract.aquatiq.com
```

Cloudflare propagation typically takes 2-5 minutes.

### Issue: Static Files Not Loading

If Django admin has no CSS/JS, ensure `ALLOWED_HOSTS` includes the subdomain:

```python
# In Django settings.py
ALLOWED_HOSTS = [
    'contract.aquatiq.com',
    'localhost',
]

# And verify CSRF settings
CSRF_TRUSTED_ORIGINS = [
    'https://contract.aquatiq.com',
]
```

### Issue: Container Not Detected by Traefik

**Restart Traefik:**
```bash
cd /opt/aquatiq/aquatiq-root-container
docker compose restart traefik
```

**Check Docker socket proxy:**
```bash
docker logs aquatiq-docker-proxy
```

---

## Django-Specific Configuration

### Environment Variables

Ensure your `.env.production` includes:

```bash
# Django settings
DJANGO_ALLOWED_HOSTS=contract.aquatiq.com,localhost
DJANGO_CSRF_TRUSTED_ORIGINS=https://contract.aquatiq.com
DJANGO_SECURE_SSL_REDIRECT=False  # Traefik handles SSL

# If using Cloudflare
DJANGO_USE_X_FORWARDED_HOST=True
DJANGO_SECURE_PROXY_SSL_HEADER=HTTP_X_FORWARDED_PROTO,https
```

### Static Files

If serving static files with Django (not recommended for production):

```python
# settings.py
STATIC_URL = '/static/'
STATIC_ROOT = '/app/staticfiles/'

# Add WhiteNoise middleware
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',  # Add this
    # ... rest of middleware
]
```

---

## Security Considerations

- ✅ Cloudflare proxy provides DDoS protection
- ✅ Automatic SSL via Cloudflare (strict mode)
- ✅ Container isolated behind Traefik reverse proxy
- ✅ Not directly exposed to internet

### Optional: Add IP Whitelist

To restrict access to specific IPs:

```yaml
labels:
  - "traefik.http.routers.contract-manager.middlewares=dynamic-ipwhitelist@file"
```

Configure whitelist in `/opt/aquatiq/aquatiq-root-container/cloudflare-certs/middlewares.yml`.

### Optional: Add Rate Limiting

Protect against abuse:

```yaml
labels:
  - "traefik.http.routers.contract-manager.middlewares=admin-ratelimit@file"
```

---

## Rollback Procedure

If issues occur, revert to direct port access:

```bash
cd /opt/aquatiq-contract-manager

# Remove Traefik labels from docker-compose.yml
# Expose port directly
docker compose down
docker compose up -d

# Access via: http://31.97.38.31:8001
```

Or restore path-based routing:
```yaml
labels:
  - "traefik.http.routers.contract-manager.rule=Host(`tools.aquatiq.com`) && PathPrefix(`/contracts`)"
  - "traefik.http.middlewares.contract-strip.stripprefix.prefixes=/contracts"
  - "traefik.http.routers.contract-manager.middlewares=contract-strip"
```

---

## Configuration Summary

| Component | Value |
|-----------|-------|
| **Subdomain** | `contract.aquatiq.com` |
| **Container** | `aquatiq-contract-manager` |
| **Port** | `8001` |
| **Network** | `aquatiq_default` or `internal` |
| **SSL** | Cloudflare (automatic) |
| **Router Name** | `contract-manager` |
| **Framework** | Django |

---

## Next Steps

After successful deployment:

1. ✅ Update documentation with new URL
2. ✅ Update Next.js frontend (if iframe embedding was used)
3. ✅ Configure Django ALLOWED_HOSTS and CSRF_TRUSTED_ORIGINS
4. ✅ Set up monitoring/alerts for the subdomain
5. ✅ Configure backups for `/opt/aquatiq-contract-manager`
6. ✅ Test all contract management workflows

---

## Related Documentation

- [Main Traefik Setup](./NETWORKING.md)
- [Adding More Subdomains](./ADDING_SUBDOMAINS.md)
- [Security Configuration](./SECURITY.md)
- [Superset Setup](./SUPERSET_SUBDOMAIN_SETUP.md)
