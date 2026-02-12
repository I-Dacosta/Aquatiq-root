# Adding Subdomains to Aquatiq Infrastructure

## Overview
This guide explains how to add new subdomains to your Aquatiq infrastructure using Traefik reverse proxy. Use this for any new service you want to expose on a subdomain like `service.aquatiq.com`.

## Current Subdomains

| Subdomain | Service | Location | Port |
|-----------|---------|----------|------|
| `app.aquatiq.com` | Landing Page | `/opt/aquatiq/aquatiq-root-container` | 80 |
| `n8n.aquatiq.com` | N8N Workflow | `/opt/aquatiq/aquatiq-root-container` | 5678 |
| `admin.aquatiq.com` | Gateway API | `/opt/aquatiq/aquatiq-root-container` | 7500 |
| `pgadmin.aquatiq.com` | PostgreSQL Admin | `/opt/aquatiq/aquatiq-root-container` | 80 |
| `redis.aquatiq.com` | RedisInsight | `/opt/aquatiq/aquatiq-root-container` | 5540 |
| `prometheus.aquatiq.com` | Prometheus | `/opt/aquatiq/aquatiq-root-container` | 9090 |
| `grafana.aquatiq.com` | Grafana Dashboard | `/opt/aquatiq/aquatiq-root-container` | 3000 |
| `traefik.aquatiq.com` | Traefik Dashboard | `/opt/aquatiq/aquatiq-root-container` | - |
| `superset.aquatiq.com` | Apache Superset | `/opt/aquatiq-superset` | 8088 |
| `contract.aquatiq.com` | Contract Manager | `/opt/aquatiq-contract-manager` | 8001 |

---

## Two Approaches for Adding Subdomains

### Approach A: Service in Root Container (Same docker-compose.yml)

Use this when the service is part of the main infrastructure stack.

**Example**: Adding a new monitoring tool to the root container.

### Approach B: External Service (Separate Project)

Use this when the service runs independently in its own directory.

**Example**: Superset, Contract Manager, or any standalone application.

---

## Approach A: Service in Root Container

### 1. Add DNS Record

Log in to Cloudflare → Select `aquatiq.com`:

- **Type**: `A`
- **Name**: `yourservice`
- **IPv4 address**: `31.97.38.31`
- **Proxy status**: ✅ Proxied

### 2. Add Service to docker-compose.yml

Edit `/opt/aquatiq/aquatiq-root-container/docker-compose.yml`:

```yaml
services:
  # ... existing services ...

  your-service:
    image: your-service-image:latest
    container_name: aquatiq-your-service
    restart: unless-stopped
    
    environment:
      - SERVICE_PORT=8080  # Your service port
    
    volumes:
      - your_service_data:/data
    
    networks:
      - internal  # Or aquatiq-backend, depending on needs
    
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s
    
    labels:
      - "traefik.enable=true"
      
      # HTTPS router
      - "traefik.http.routers.your-service.rule=Host(`yourservice.aquatiq.com`)"
      - "traefik.http.routers.your-service.entrypoints=websecure"
      - "traefik.http.routers.your-service.tls=true"
      - "traefik.http.services.your-service.loadbalancer.server.port=8080"
      
      # HTTP to HTTPS redirect
      - "traefik.http.routers.your-service-http.rule=Host(`yourservice.aquatiq.com`)"
      - "traefik.http.routers.your-service-http.entrypoints=web"
      - "traefik.http.routers.your-service-http.middlewares=redirect-to-https@file"

volumes:
  # ... existing volumes ...
  your_service_data:
    driver: local
```

### 3. Deploy

```bash
cd /opt/aquatiq/aquatiq-root-container
docker compose up -d your-service
```

---

## Approach B: External Service

### 1. Add DNS Record

Same as Approach A:

- **Type**: `A`
- **Name**: `yourservice`
- **IPv4 address**: `31.97.38.31`
- **Proxy status**: ✅ Proxied

### 2. Ensure Network Connectivity

Your external service must connect to Traefik's network. Choose one:

#### Option 1: Use Existing Network

In your service's `docker-compose.yml`:

```yaml
networks:
  aquatiq_default:
    external: true
    name: aquatiq_default
```

Or:

```yaml
networks:
  internal:
    external: true
    name: internal
```

#### Option 2: Connect Manually

```bash
docker network connect internal your-container-name
```

### 3. Add Traefik Labels

Edit your service's `docker-compose.yml` (e.g., `/opt/your-service/docker-compose.yml`):

```yaml
services:
  your-service:
    image: your-service-image:latest
    container_name: aquatiq-your-service
    restart: unless-stopped
    
    # ... your existing configuration ...
    
    networks:
      - internal  # Or aquatiq_default
    
    labels:
      # Enable Traefik routing
      - "traefik.enable=true"
      
      # HTTPS router
      - "traefik.http.routers.your-service.rule=Host(`yourservice.aquatiq.com`)"
      - "traefik.http.routers.your-service.entrypoints=websecure"
      - "traefik.http.routers.your-service.tls=true"
      - "traefik.http.services.your-service.loadbalancer.server.port=8080"
      
      # HTTP to HTTPS redirect
      - "traefik.http.routers.your-service-http.rule=Host(`yourservice.aquatiq.com`)"
      - "traefik.http.routers.your-service-http.entrypoints=web"
      - "traefik.http.routers.your-service-http.middlewares=redirect-to-https@file"
      
      # Specify which network Traefik should use
      - "traefik.docker.network=internal"

networks:
  internal:
    external: true
    name: internal
```

### 4. Deploy

```bash
cd /opt/your-service
docker compose down
docker compose up -d
```

---

## Label Reference

### Required Labels

```yaml
# Enable Traefik for this container
- "traefik.enable=true"

# Define routing rule (subdomain)
- "traefik.http.routers.SERVICE-NAME.rule=Host(`subdomain.aquatiq.com`)"

# Use HTTPS entrypoint
- "traefik.http.routers.SERVICE-NAME.entrypoints=websecure"

# Enable TLS/SSL
- "traefik.http.routers.SERVICE-NAME.tls=true"

# Specify container port
- "traefik.http.services.SERVICE-NAME.loadbalancer.server.port=8080"
```

### Optional Labels

```yaml
# HTTP to HTTPS redirect
- "traefik.http.routers.SERVICE-NAME-http.rule=Host(`subdomain.aquatiq.com`)"
- "traefik.http.routers.SERVICE-NAME-http.entrypoints=web"
- "traefik.http.routers.SERVICE-NAME-http.middlewares=redirect-to-https@file"

# Specify network (if multiple networks)
- "traefik.docker.network=internal"

# Add IP whitelist
- "traefik.http.routers.SERVICE-NAME.middlewares=dynamic-ipwhitelist@file"

# Add rate limiting
- "traefik.http.routers.SERVICE-NAME.middlewares=admin-ratelimit@file"

# Add basic auth
- "traefik.http.routers.SERVICE-NAME.middlewares=traefik-auth@file"

# Chain multiple middlewares
- "traefik.http.routers.SERVICE-NAME.middlewares=dynamic-ipwhitelist@file,admin-ratelimit@file"
```

---

## Naming Conventions

Use consistent naming for router and service names:

| Component | Pattern | Example |
|-----------|---------|---------|
| **Container** | `aquatiq-service-name` | `aquatiq-superset-app` |
| **Router (HTTPS)** | `service-name` | `superset` |
| **Router (HTTP)** | `service-name-http` | `superset-http` |
| **Service** | `service-name` | `superset` |
| **Network** | `internal` or `aquatiq_default` | `internal` |

---

## Verification Checklist

After adding a subdomain:

- [ ] DNS record added in Cloudflare (A record, proxied)
- [ ] Container connected to Traefik network (`internal` or `aquatiq_default`)
- [ ] Traefik labels added to service
- [ ] Container restarted/recreated
- [ ] Traefik detected the service: `docker logs aquatiq-traefik | grep service-name`
- [ ] Service accessible via HTTPS: `curl -I https://subdomain.aquatiq.com`
- [ ] HTTP redirects to HTTPS
- [ ] SSL certificate valid (Cloudflare)
- [ ] Container health check passing: `docker ps | grep service-name`

---

## Troubleshooting

### DNS Not Resolving

```bash
# Check DNS propagation
dig subdomain.aquatiq.com
nslookup subdomain.aquatiq.com

# Wait 2-5 minutes for Cloudflare propagation
```

### 502 Bad Gateway

```bash
# Check container running
docker ps | grep service-name

# Check container logs
docker logs aquatiq-service-name

# Check network connectivity
docker network inspect internal | grep -A 5 service-name
docker exec aquatiq-traefik ping aquatiq-service-name

# Test service directly
curl -I http://localhost:SERVICE_PORT
```

### Traefik Not Detecting Service

```bash
# Check Traefik logs
docker logs aquatiq-traefik | grep service-name

# Restart Traefik
cd /opt/aquatiq/aquatiq-root-container
docker compose restart traefik

# Verify Docker socket proxy
docker logs aquatiq-docker-proxy
```

### SSL Certificate Error

With Cloudflare proxy enabled (orange cloud):
- SSL is handled by Cloudflare
- Ensure Cloudflare SSL mode is **Full** or **Strict**
- Traefik receives traffic from Cloudflare proxy

### Container Not on Same Network

```bash
# List available networks
docker network ls

# Connect container to network
docker network connect internal aquatiq-service-name

# Verify connection
docker network inspect internal | grep service-name
```

---

## Security Best Practices

### 1. Use IP Whitelisting

For admin interfaces, restrict access:

```yaml
labels:
  - "traefik.http.routers.service.middlewares=dynamic-ipwhitelist@file"
```

Configure in `/opt/aquatiq/aquatiq-root-container/cloudflare-certs/middlewares.yml`:

```yaml
http:
  middlewares:
    dynamic-ipwhitelist:
      ipWhiteList:
        sourceRange:
          - "127.0.0.1/32"
          - "YOUR_OFFICE_IP/32"
```

### 2. Add Rate Limiting

Protect against abuse:

```yaml
labels:
  - "traefik.http.routers.service.middlewares=admin-ratelimit@file"
```

### 3. Use Basic Authentication

For sensitive services:

```yaml
labels:
  - "traefik.http.routers.service.middlewares=traefik-auth@file"
```

### 4. Enable Health Checks

Always include health checks:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:PORT/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 15s
```

---

## Middleware Configuration

Edit `/opt/aquatiq/aquatiq-root-container/cloudflare-certs/middlewares.yml`:

```yaml
http:
  middlewares:
    # HTTP to HTTPS redirect
    redirect-to-https:
      redirectScheme:
        scheme: https
        permanent: true
    
    # IP Whitelist
    dynamic-ipwhitelist:
      ipWhiteList:
        sourceRange:
          - "127.0.0.1/32"
          - "YOUR_IP/32"
    
    # Rate Limiting
    admin-ratelimit:
      rateLimit:
        average: 100
        burst: 50
        period: 1m
    
    # Cloudflare Security Headers
    cloudflare-security:
      headers:
        customRequestHeaders:
          X-Forwarded-Proto: "https"
        customResponseHeaders:
          X-Frame-Options: "SAMEORIGIN"
          X-Content-Type-Options: "nosniff"
```

---

## Quick Reference Templates

### Web Application (Port 8080)

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`myapp.aquatiq.com`)"
  - "traefik.http.routers.myapp.entrypoints=websecure"
  - "traefik.http.routers.myapp.tls=true"
  - "traefik.http.services.myapp.loadbalancer.server.port=8080"
  - "traefik.http.routers.myapp-http.rule=Host(`myapp.aquatiq.com`)"
  - "traefik.http.routers.myapp-http.entrypoints=web"
  - "traefik.http.routers.myapp-http.middlewares=redirect-to-https@file"
```

### API Service (Port 5000)

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapi.rule=Host(`api.aquatiq.com`)"
  - "traefik.http.routers.myapi.entrypoints=websecure"
  - "traefik.http.routers.myapi.tls=true"
  - "traefik.http.services.myapi.loadbalancer.server.port=5000"
  - "traefik.http.routers.myapi.middlewares=admin-ratelimit@file"
```

### Admin Interface (Port 3000, Protected)

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myadmin.rule=Host(`myadmin.aquatiq.com`)"
  - "traefik.http.routers.myadmin.entrypoints=websecure"
  - "traefik.http.routers.myadmin.tls=true"
  - "traefik.http.services.myadmin.loadbalancer.server.port=3000"
  - "traefik.http.routers.myadmin.middlewares=dynamic-ipwhitelist@file,admin-ratelimit@file"
```

---

## Related Documentation

- [Networking Guide](./NETWORKING.md)
- [Security Configuration](./SECURITY.md)
- [Superset Setup](./SUPERSET_SUBDOMAIN_SETUP.md)
- [Contract Manager Setup](./CONTRACT_MANAGER_SUBDOMAIN_SETUP.md)
- [Traefik Official Docs](https://doc.traefik.io/traefik/)

---

## Support

For issues:
1. Check container logs: `docker logs <container-name>`
2. Check Traefik logs: `docker logs aquatiq-traefik`
3. Verify DNS: `dig subdomain.aquatiq.com`
4. Test network: `docker exec aquatiq-traefik ping <container-name>`
5. Review this guide's troubleshooting section
