# Aquatiq Root Container System

> **Centralized Infrastructure Stack for Local Development & Production Deployment**

The Aquatiq Root Container System is a comprehensive, production-grade infrastructure foundation that provides essential services (PostgreSQL, Redis, NATS, MinIO, n8n, management tools) with a unified configuration approach for development and deployment.

---

## 📋 Table of Contents

- [Why This Exists](#-why-this-exists)
- [What It Does](#-what-it-does)
- [Architecture](#-architecture)
- [System Components](#-system-components)
- [Getting Started](#-getting-started)
- [Usage Scenarios](#-usage-scenarios)
- [Network Architecture](#-network-architecture)
- [Port Configuration](#-port-configuration)
- [Security Features](#-security-features)
- [Performance & Benchmarks](#-performance--benchmarks)
- [Deployment](#-deployment)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 Why This Exists

### The Problem
Modern development workflows often face these challenges:

1. **Service Duplication**: Running PostgreSQL, Redis, NATS separately for each project wastes resources
2. **Configuration Drift**: Different setups between dev/staging/production lead to "works on my machine" issues
3. **Resource Overhead**: Multiple instances of the same service consume unnecessary CPU/memory
4. **Complex Networking**: Managing connections between microservices becomes unwieldy
5. **Inconsistent Security**: Ad-hoc security configurations across different projects

### The Solution
Aquatiq Root Container provides:

- **Single Source of Truth**: One centralized infrastructure stack for all projects
- **Resource Efficiency**: Shared services reduce memory/CPU footprint by 60-80%
- **Environment Parity**: Identical configuration for local/staging/production
- **Network Isolation**: Secure multi-tenant networking with separate namespaces
- **Production-Ready Security**: Rate limiting, IP whitelisting, audit logging built-in

---

## 🏗️ What It Does

### Core Functions

1. **Shared Service Layer**
   - PostgreSQL with multi-database support
   - Redis with password authentication
   - NATS message queue with token auth
   - MinIO object storage with S3 API
   - n8n workflow automation
   - pgvector extension automatically enabled in all local dev databases

2. **Infrastructure Management**
   - Aquatiq Gateway: REST/gRPC API for Docker management, database operations, IP whitelisting
   - pgAdmin: Visual PostgreSQL administration
   - RedisInsight: Advanced Redis management

3. **Network Segmentation**
   - `aquatiq-local`: Company/team projects
   - `ima-local`: Personal/private projects
   - Isolated but accessible from both networks

4. **Security & Resilience**
   - Built-in rate limiting (69 req/s success rate, 31 req/s throttled in benchmarks)
   - Docker socket proxy for secure container management
   - Secret management via Docker secrets (production)
   - Comprehensive audit logging

---

## 🔧 Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                   Aquatiq Root Container                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│  │ PostgreSQL   │  │    Redis     │  │     NATS     │  │    MinIO     │
│  │   :5432      │  │    :6379     │  │    :4222     │  │    :9010     │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘
│         ▲                                                   │
│         │ (one-shot init)                                   │
│  ┌──────────────┐                                           │
│  │ pgvector-init│  ensures `vector` extension in all DBs    │
│  └──────────────┘                                           │
│                                                             │
│  ┌──────────────────────────────────────────────────┐       │
│  │         Aquatiq Gateway (:7500 REST)            │       │
│  │  - Docker Management    - Database Operations   │       │
│  │  - IP Whitelisting      - Rate Limiting         │       │
│  │  - Audit Logging        - Health Checks         │       │
│  └──────────────────────────────────────────────────┘       │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │     n8n      │  │   pgAdmin    │  │ RedisInsight │       │
│  │   :5678      │  │    :5050     │  │    :5540     │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         │                                    │
    aquatiq-local                        ima-local
         │                                    │
   ┌─────┴─────┐                      ┌──────┴──────┐
   │ Company   │                      │  Personal   │
   │ Projects  │                      │  Projects   │
   └───────────┘                      └─────────────┘
````

---

## 📦 System Components

### Core Services

| Service                           | Port       | Purpose                                           | Networks |
| --------------------------------- | ---------- | ------------------------------------------------- | -------- |
| **PostgreSQL 17**                 | 5432       | Primary database (n8n, aquatiq_risk, aquatiq_dev) | Both     |
| **Redis 7**                       | 6379       | Cache & queue backend                             | Both     |
| **NATS 2.10**                     | 4222, 8222 | Message queue & pub/sub                           | Both     |
| **MinIO**                         | 9010, 9011 | Object storage with S3 API                        | Both     |
| **pgvector (Postgres extension)** | n/a        | Vector similarity extension for Postgres          | n/a      |
| **n8n**                           | 5678       | Workflow automation                               | Both     |

### Management Layer

| Service             | Port                      | Purpose             | Access         |
| ------------------- | ------------------------- | ------------------- | -------------- |
| **Aquatiq Gateway** | 7500 (REST), 50051 (gRPC) | Infrastructure API  | Both networks  |
| **pgAdmin**         | 5050                      | PostgreSQL web UI   | Localhost only |
| **RedisInsight**    | 5540                      | Redis management UI | Localhost only |

### Initialization / Utility

| Component               | Purpose                                                                                                                      | Notes                                                 |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| **pgvector-init**       | One-shot container that ensures `CREATE EXTENSION IF NOT EXISTS vector;` is executed in `n8n`, `aquatiq_risk`, `aquatiq_dev` | Automatically removed after start by `start-local.sh` |
| **Docker Socket Proxy** | Restricted Docker API access (read-only)                                                                                     | Used by Aquatiq Gateway                               |

---

## 🚀 Getting Started

### Local Development Credentials

Local credentials are defined in `.env.local` (for core services) plus static defaults for MinIO and admin tools.

**Default values for local environment (`.env.local`):**

| Service             | Credential        | Value                                                                       |
| ------------------- | ----------------- | --------------------------------------------------------------------------- |
| **PostgreSQL**      | Username          | `aquatiq`                                                                   |
|                     | Password          | `postgres` (`POSTGRES_PASSWORD`)                                            |
|                     | Connection String | `postgres://aquatiq:postgres@localhost:5432/aquatiq_dev`                    |
| **Redis**           | Password          | `redis` (`REDIS_PASSWORD`)                                                  |
|                     | Connection String | `redis://:redis@localhost:6379`                                             |
| **NATS**            | Auth Token        | `nats` (`NATS_AUTH_TOKEN`)                                                  |
|                     | Connection String | `nats://localhost:4222?token=nats`                                          |
| **MinIO**           | Root User         | `admin` (static for local)                                                  |
|                     | Root Password     | `aquatiq-minio-2024` (static for local)                                     |
|                     | S3 Endpoint       | `http://localhost:9010`                                                     |
|                     | Console URL       | `http://localhost:9011`                                                     |
| **n8n**             | Encryption Key    | `n8n_encryption_key` (`N8N_ENCRYPTION_KEY`)                                 |
|                     | Setup             | First-time setup required at [http://localhost:5678](http://localhost:5678) |
| **pgAdmin**         | Email             | `admin@aquatiq.com`                                                         |
|                     | Password          | `admin`                                                                     |
|                     | URL               | [http://localhost:5050](http://localhost:5050)                              |
| **RedisInsight**    | URL               | [http://localhost:5540](http://localhost:5540)                              |
| **Aquatiq Gateway** | API Key           | `gateway` (`INTEGRATION_GATEWAY_API_KEY`)                                   |
|                     | REST API          | [http://localhost:7500](http://localhost:7500)                              |
|                     | gRPC API          | localhost:50051                                                             |

**All core credentials for local development are stored in `.env.local`.**
MinIO and admin UI credentials are static for local development and must **never** be reused in production.

⚠️ **Important**: These are development-only credentials. **Never use these in production!**

### Prerequisites

* Docker Engine 24.0+ & Docker Compose v2
* macOS, Linux, or WSL2
* Minimum 4GB RAM, 10GB disk space

### Quick Start (Local Development)

```bash
# 1. Clone repository
cd aquatiq-root-container

# 2. Start local stack (always uses .env.local)
./start-local.sh

# If you want a completely fresh environment:
./reset-local.sh
./start-local.sh

# 3. Verify services
docker ps --filter "name=aquatiq-.*-local"
```

`start-local.sh` will:

* Ensure `.env.local` exists (creates it with default values if missing)
* Start all local infrastructure containers using `docker-compose.local.yml`
* Wait for the `aquatiq-pgvector-init` job to finish
* Remove the `aquatiq-pgvector-init` container after successful completion

### Access URLs

* **n8n**: [http://localhost:5678](http://localhost:5678) (first-time setup required)
* **pgAdmin**: [http://localhost:5050](http://localhost:5050) ([admin@aquatiq.com](mailto:admin@aquatiq.com) / admin)
* **RedisInsight**: [http://localhost:5540](http://localhost:5540)
* **MinIO Console**: [http://localhost:9011](http://localhost:9011) (admin / aquatiq-minio-2024)
* **Aquatiq Gateway**: [http://localhost:7500/health](http://localhost:7500/health)

---

### Local Development Usage (English)

This repository ships with a fully self-contained **local infrastructure stack** for development.

**Files involved:**

* `docker-compose.local.yml` – defines the local services
* `.env.local` – local-only environment variables
* `start-local.sh` – convenience script to start the stack
* `reset-local.sh` – convenience script to wipe all local data

**1. Start the local stack**

```bash
./start-local.sh
```

This will:

* Use `.env.local` for:

  * `POSTGRES_PASSWORD=postgres`
  * `REDIS_PASSWORD=redis`
  * `NATS_AUTH_TOKEN=nats`
  * `INTEGRATION_GATEWAY_API_KEY=gateway`
  * `DOMAIN=localhost`
  * `N8N_ENCRYPTION_KEY=n8n_encryption_key`
  * `GENERIC_TIMEZONE=Europe/Oslo`
* Start:

  * PostgreSQL (`aquatiq`, DBs: `n8n`, `aquatiq_risk`, `aquatiq_dev`)
  * Redis
  * NATS
  * MinIO
  * n8n
  * Aquatiq Gateway
  * pgAdmin
  * RedisInsight
* Run the `aquatiq-pgvector-init` one-shot container:

  * Waits until PostgreSQL is ready
  * Runs `CREATE EXTENSION IF NOT EXISTS vector;` in `n8n`, `aquatiq_risk`, `aquatiq_dev`
  * Is removed automatically after completion

**2. Reset the local environment**

```bash
./reset-local.sh
./start-local.sh
```

`reset-local.sh` will:

* Stop and remove all containers from `docker-compose.local.yml`
* Remove all related volumes (`postgres_local_data`, `redis_local_data`, `n8n_local_data`, `minio-data`, etc.)
* Attempt to remove the `aquatiq-local` and `ima-local` networks if they are not used by other containers

> ⚠️ This is destructive – use it only when you explicitly want to wipe all local data.

**3. Connecting from your own services**

Example `docker-compose.yml` for a service using the shared stack:

```yaml
services:
  my-app:
    image: my-app:latest
    environment:
      DATABASE_URL: postgres://aquatiq:postgres@postgres:5432/aquatiq_dev
      REDIS_URL: redis://:redis@redis:6379
      NATS_URL: nats://nats:4222?token=nats
      MINIO_ENDPOINT: http://minio:9000
      MINIO_ACCESS_KEY: admin
      MINIO_SECRET_KEY: aquatiq-minio-2024
    networks:
      - ima-local  # or aquatiq-local for company projects

networks:
  ima-local:
    external: true
```

**4. Verifying pgvector**

```bash
docker exec -it aquatiq-postgres-local psql -U aquatiq -d aquatiq_dev -c "\dx"
```

You should see `vector` in the list of installed extensions.

---

### Lokal bruk – norsk versjon

Dette repoet gir deg en komplett **lokal infrastrukturstack** for utvikling.

**Filer som brukes:**

* `docker-compose.local.yml` – definerer alle tjenester lokalt
* `.env.local` – miljøvariabler kun for lokal utvikling
* `start-local.sh` – enkel oppstart av hele stacken
* `reset-local.sh` – nullstiller all lokal data

**1. Starte lokal stack**

```bash
./start-local.sh
```

Skriptet:

* Sikrer at `.env.local` finnes (oppretter med standardverdier hvis den mangler)
* Starter:

  * PostgreSQL (bruker `aquatiq`, databaser: `n8n`, `aquatiq_risk`, `aquatiq_dev`)
  * Redis
  * NATS
  * MinIO
  * n8n
  * Aquatiq Gateway
  * pgAdmin
  * RedisInsight
* Kjører engangs-containeren `aquatiq-pgvector-init` som:

  * Venter til PostgreSQL er klar
  * Kjører `CREATE EXTENSION IF NOT EXISTS vector;` i `n8n`, `aquatiq_risk`, `aquatiq_dev`
  * Blir automatisk slettet når den er ferdig

**2. Nullstille lokal miljø (wipe alt)**

```bash
./reset-local.sh
./start-local.sh
```

`reset-local.sh`:

* Stopper og sletter alle containere definert i `docker-compose.local.yml`
* Sletter alle tilhørende volumer:

  * `postgres_local_data`, `redis_local_data`, `n8n_local_data`, `minio-data` osv.
* Forsøker å slette nettverkene `aquatiq-local` og `ima-local` dersom de ikke er i bruk

> ⚠️ Dette er destruktivt – bruk kun når du VIL slette all lokal data.

**3. Koble til fra egne tjenester**

```yaml
services:
  min-tjeneste:
    image: min-tjeneste:local
    environment:
      DATABASE_URL: postgres://aquatiq:postgres@postgres:5432/aquatiq_dev
      REDIS_URL: redis://:redis@redis:6379
      NATS_URL: nats://nats:4222?token=nats
      MINIO_ENDPOINT: http://minio:9000
      MINIO_ACCESS_KEY: admin
      MINIO_SECRET_KEY: aquatiq-minio-2024
    networks:
      - ima-local  # eller aquatiq-local

networks:
  ima-local:
    external: true
```

**4. Verifisere pgvector**

```bash
docker exec -it aquatiq-postgres-local psql -U aquatiq -d aquatiq_dev -c "\dx"
```

Du skal se `vector`-extension i listen.

---

## 💼 Usage Scenarios

### 🏠 Local Development (docker-compose.local.yml)

**Purpose:** Development on your local machine with simple, explicit credentials.

**Setup:**

```bash
# Start local stack (preferred)
./start-local.sh

# Or manually
docker compose -f docker-compose.local.yml --env-file .env.local up -d
```

**Connection Examples:**

```yaml
# your-app/docker-compose.yml
services:
  my-app:
    image: my-app:latest
    environment:
      DATABASE_URL: postgres://aquatiq:postgres@postgres:5432/aquatiq_dev
      REDIS_URL: redis://:redis@redis:6379
      NATS_URL: nats://nats:4222?token=nats
      MINIO_ENDPOINT: http://minio:9000
      MINIO_ACCESS_KEY: admin
      MINIO_SECRET_KEY: aquatiq-minio-2024
    networks:
      - ima-local  # or aquatiq-local for company projects

networks:
  ima-local:
    external: true
```

**Credentials (from `.env.local` + static local defaults):**

* PostgreSQL: `aquatiq` / `postgres`
* Redis: `redis`
* NATS: `nats`
* MinIO: `admin` / `aquatiq-minio-2024`
* Gateway API: `gateway`
* pgvector: available as Postgres extension `vector` in `n8n`, `aquatiq_risk`, `aquatiq_dev`

**⚠️ Security:** These are simple passwords for local development only. Never expose 127.0.0.1 bindings directly to the internet!

**🔄 Reset Script:** If something looks wrong or you want a clean slate, run `./reset-local.sh` and then `./start-local.sh`.

---

### 🏢 Production Deployment (docker-compose.yml or docker-compose.flexible.yml)

*(unchanged semantics, still relevant for VPS/Cloudflare setups)*

**Purpose:** VPS deployment with strong credentials and SSL

```bash
# 1. Generate strong secrets (do this once)
openssl rand -base64 32 > secrets/postgres_password.txt
openssl rand -base64 32 > secrets/redis_password.txt
openssl rand -base64 32 > secrets/nats_auth_token.txt
openssl rand -base64 32 > secrets/n8n_encryption_key.txt

# 2. Update .env with VPS IP and strong passwords
vim .env  # Set VPS_IP, POSTGRES_PASSWORD, etc.

# 3. Deploy to VPS
scp -r . root@your-vps:/opt/aquatiq/
ssh root@your-vps "cd /opt/aquatiq && docker compose -f docker-compose.flexible.yml --env-file .env up -d"
```

---

### 📊 Environment Comparison

| Feature          | Local (.env.local)                                 | Production (.env)                         |
| ---------------- | -------------------------------------------------- | ----------------------------------------- |
| **Passwords**    | Simple dev passwords (`postgres`, `redis`, `nats`) | Strong 32+ char random                    |
| **Port Binding** | `127.0.0.1:*` (localhost only)                     | `0.0.0.0:*` (with firewall/reverse proxy) |
| **SSL/TLS**      | Not required                                       | Cloudflare / Traefik SSL                  |
| **Networks**     | `aquatiq-local`, `ima-local`                       | `aquatiq-network`                         |
| **Secrets**      | Plain `.env.local` file (ignored in VCS)           | Docker secrets from files                 |
| **Access**       | Direct port access                                 | Traefik reverse proxy                     |
| **Monitoring**   | Optional                                           | Recommended (Grafana, etc.)               |

---

## 🌐 Network Architecture

### Two-Network Design

**aquatiq-local** (Company/Team Projects)

* Access to all shared services
* Intended for production-bound applications
* Shared with team members

**ima-local** (Personal/Private Projects)

* Access to same services, isolated namespace
* For experimentation and personal work
* No cross-contamination with company projects

### Inter-Service Communication

Services communicate using container names as hostnames:

```python
# Python example
import psycopg2
conn = psycopg2.connect(
    host="postgres",  # Container name = hostname
    port=5432,
    database="aquatiq_dev",
    user="aquatiq",
    password="postgres",  # from .env.local
)
```

```javascript
// Node.js example (Redis)
const redis = require('redis');
const client = redis.createClient({
  host: 'redis',
  port: 6379,
  password: 'redis', // from .env.local
});

// MinIO example
const Minio = require('minio');
const minioClient = new Minio.Client({
  endPoint: 'minio',
  port: 9000,
  useSSL: false,
  accessKey: 'admin',
  secretKey: 'aquatiq-minio-2024'
});
```

---

## 🔌 Port Configuration

### Local Development Ports (Localhost Only)

| Port  | Service              | Protocol | Binding   |
| ----- | -------------------- | -------- | --------- |
| 5432  | PostgreSQL           | TCP      | 127.0.0.1 |
| 6379  | Redis                | TCP      | 127.0.0.1 |
| 4222  | NATS                 | TCP      | 127.0.0.1 |
| 8222  | NATS Monitoring      | HTTP     | 127.0.0.1 |
| 5678  | n8n                  | HTTP     | 127.0.0.1 |
| 5050  | pgAdmin              | HTTP     | 127.0.0.1 |
| 5540  | RedisInsight         | HTTP     | 127.0.0.1 |
| 7500  | Aquatiq Gateway REST | HTTP     | 127.0.0.1 |
| 50051 | Aquatiq Gateway gRPC | TCP      | 127.0.0.1 |
| 9010  | MinIO S3 API         | HTTP     | 127.0.0.1 |
| 9011  | MinIO Console        | HTTP     | 127.0.0.1 |

**Why Custom Ports?**

* **7500**: Non-standard port harder to guess than 5001
* **50051**: Standard 5-digit gRPC port for compatibility
* All services bind to `127.0.0.1` locally to prevent external access

---

## 🔒 Security Features

*(unchanged conceptually – still valid for production setups, while local uses simplified credentials)*

### 1. Rate Limiting

[...]

*(keep this section as-is unless you want to trim it – omitted here for brevity in this snippet)*

---

## ⚡ Performance & Benchmarks

*(same as before – your benchmark section can remain unchanged)*

---

## 🚢 Deployment

### Local Development

```bash
# Preferred:
./start-local.sh

# Manual:
docker compose -f docker-compose.local.yml --env-file .env.local up -d

# Stop stack
docker compose -f docker-compose.local.yml down

# View logs
docker compose -f docker-compose.local.yml logs -f [service]

# Restart specific service
docker compose -f docker-compose.local.yml restart postgres
```

### Environment Files

**Local Development (.env.local):**

```env
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
```

**Production (.env):**

*(unchanged from your previous setup, still includes strong random values and SSL configuration)*

---

## 🔍 Troubleshooting

### Services Won't Start

```bash
# Check logs
docker compose -f docker-compose.local.yml logs [service]

# Check port conflicts
lsof -i :5432 -i :6379 -i :4222

# If local state looks broken:
./reset-local.sh
./start-local.sh
```

### Database Connection Issues

```bash
# Test PostgreSQL connection
docker exec -it aquatiq-postgres-local psql -U aquatiq -d aquatiq_dev

# List databases
docker exec -it aquatiq-postgres-local psql -U aquatiq -c "\l"

# Test Redis connection
docker exec -it aquatiq-redis-local redis-cli -a redis ping
```

### Network Issues

```bash
# Verify networks exist
docker network ls | grep -E "aquatiq-local|ima-local"

# Inspect network
docker network inspect aquatiq-local

# Connect container to network
docker network connect aquatiq-local <container-name>
```

### Gateway Not Responding

```bash
# Check health
curl http://localhost:7500/health

# View gateway logs
docker logs aquatiq-gateway-local --tail 50 -f

# Restart gateway
docker compose -f docker-compose.local.yml restart aquatiq-gateway
```

---

## 📚 Documentation

*(same as before – links to docs, security, networking, changelog, contributing, etc.)*

---

## 📊 Project Status

![Status](https://img.shields.io/badge/status-production-green)
![Version](https://img.shields.io/badge/version-2.0.1-blue)
![Last Updated](https://img.shields.io/badge/updated-November%2028%202025-orange)

**Last Updated**: November 28, 2025
**Maintained By**: Aquatiq Infrastructure Team
**Environment**: Production-Ready


