# Superset Subdomain Setup Guide

## Overview
Configure `superset.aquatiq.com` to route through Traefik in `/opt/aquatiq/aquatiq-root-container` to your Superset instance at `/opt/aquatiq-superset`.

## Prerequisites
- Traefik running in `/opt/aquatiq/aquatiq-root-container`
- Superset container in `/opt/aquatiq-superset`
- Both connected to `aquatiq_default` or `internal` network
- Cloudflare DNS configured

---

## Step 1: Configure Cloudflare DNS

1. Log in to Cloudflare dashboard
2. Select domain: `aquatiq.com`
3. Add DNS record:
   - **Type**: `A`
   - **Name**: `superset`
   - **IPv4 address**: `31.97.38.31` (your VPS IP)
   - **Proxy status**: ✅ Proxied (orange cloud)
   - **TTL**: Auto

---

## Step 2: Add Traefik Labels to Superset

Edit `/opt/aquatiq-superset/docker-compose.yml` (or `docker-compose.prod.yml`):

```yaml
services:
  superset:
    image: apache/superset:4.0.1
    container_name: aquatiq-superset-app
    restart: unless-stopped
    
    # ... your existing environment, volumes, etc. ...
    
    networks:
      - aquatiq_default  # Must match Traefik's network
    
    labels:
      # Enable Traefik routing
      - "traefik.enable=true"
      
      # HTTPS router
      - "traefik.http.routers.superset.rule=Host(`superset.aquatiq.com`)"
      - "traefik.http.routers.superset.entrypoints=websecure"
      - "traefik.http.routers.superset.tls=true"
      - "traefik.http.services.superset.loadbalancer.server.port=8088"
      
      # HTTP to HTTPS redirect
      - "traefik.http.routers.superset-http.rule=Host(`superset.aquatiq.com`)"
      - "traefik.http.routers.superset-http.entrypoints=web"
      - "traefik.http.routers.superset-http.middlewares=redirect-to-https@file"
      
      # Specify which network Traefik should use
      - "traefik.docker.network=aquatiq_default"

networks:
  aquatiq_default:
    external: true
    name: aquatiq_default
```

> **Important**: If your Traefik is on the `internal` network, change `aquatiq_default` to `internal`.

---

## Step 3: Verify Network Connectivity

Check that both containers share a network:

```bash
# List Traefik networks
docker inspect aquatiq-traefik | grep -A 10 Networks

# List Superset networks
docker inspect aquatiq-superset-app | grep -A 10 Networks
```

If they don't share a network, connect Superset to Traefik's network:

```bash
# Connect to internal network (if that's where Traefik is)
docker network connect internal aquatiq-superset-app

# Or connect to aquatiq_default
docker network connect aquatiq_default aquatiq-superset-app
```

---

## Step 4: Deploy Configuration

```bash
# SSH to VPS
ssh root@31.97.38.31

# Navigate to Superset directory
cd /opt/aquatiq-superset

# Restart Superset with new labels
docker compose down
docker compose up -d

# Verify container is running
docker ps | grep superset
```

Traefik will automatically detect the new labels within 30 seconds.

---

## Step 5: Verify Deployment

### Check Traefik Detection

```bash
docker logs aquatiq-traefik | grep superset
```

Expected output:
```
level=info msg="Creating Router superset@docker"
level=info msg="Creating Service superset@docker"
```

### Test Access

```bash
# From VPS
curl -I http://localhost:8088

# From external (after DNS propagation)
curl -I https://superset.aquatiq.com
```

### Browser Test

Open: `https://superset.aquatiq.com`

You should see the Superset login page with valid SSL.

---

## Troubleshooting

### Issue: 502 Bad Gateway

**Check container status:**
```bash
docker ps | grep superset
docker logs aquatiq-superset-app
```

**Check network connectivity:**
```bash
docker network inspect internal | grep -A 5 superset
docker exec aquatiq-traefik ping aquatiq-superset-app
```

### Issue: DNS Not Resolving

**Wait for propagation:**
```bash
dig superset.aquatiq.com
nslookup superset.aquatiq.com
```

Cloudflare propagation typically takes 2-5 minutes.

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

## Security Considerations

- ✅ Cloudflare proxy provides DDoS protection
- ✅ Automatic SSL via Cloudflare (strict mode)
- ✅ Container isolated behind Traefik reverse proxy
- ✅ Not directly exposed to internet

### Optional: Add IP Whitelist

If you want to restrict access to specific IPs, add this middleware:

```yaml
labels:
  - "traefik.http.routers.superset.middlewares=dynamic-ipwhitelist@file"
```

Then configure the whitelist in `/opt/aquatiq/aquatiq-root-container/cloudflare-certs/middlewares.yml`.

---

## Configuration Summary

| Component | Value |
|-----------|-------|
| **Subdomain** | `superset.aquatiq.com` |
| **Container** | `aquatiq-superset-app` |
| **Port** | `8088` |
| **Network** | `aquatiq_default` or `internal` |
| **SSL** | Cloudflare (automatic) |
| **Router Name** | `superset` |

---

## Related Documentation

- [Main Traefik Setup](./NETWORKING.md)
- [Adding More Subdomains](./ADDING_SUBDOMAINS.md)
- [Security Configuration](./SECURITY.md)
