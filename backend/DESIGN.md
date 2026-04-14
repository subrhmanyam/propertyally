# Backend Design Document — Property Management Platform
### Python · FastAPI · Alembic · PostgreSQL · PL-SQL · Clean Architecture

---

## 1. Overview

Microservice-based backend for the Bogineni Group property management platform. Each bounded domain is an independent Python FastAPI service. Services communicate over REST (internal) and publish domain events via a message queue (async flows). All services share a common Alembic-managed PostgreSQL database cluster (separate schemas per service).

---

## 2. Architecture Principles

- **Clean Architecture** in every service: `domain → application → infrastructure → interfaces`
- **Separation of Concerns**: no SQL in controllers, no HTTP in repositories, no business logic in routes
- **API Versioning**: all routes prefixed `/api/v1/`
- **Auth**: JWT Bearer tokens, validated by `auth-service`; all other services validate the token via a shared middleware
- **Migrations**: Alembic per service, never manual DB changes
- **PL-SQL**: complex atomic operations (rent calculations, ledger postings) implemented as PostgreSQL stored procedures called by repositories

---

## 3. Services

| Service | Port | Responsibility |
|---|---|---|
| `auth-service` | 8001 | Authentication, authorization, roles, JWT |
| `property-service` | 8002 | Properties, units, amenities |
| `tenant-service` | 8003 | Tenant profiles, screening |
| `application-service` | 8004 | Rental application forms, submissions |
| `accounting-service` | 8005 | Rent roll, payments, invoices, ledger |
| `maintenance-service` | 8006 | Maintenance requests, work orders, vendors |
| `listing-service` | 8007 | Public listing website, availability |
| `reports-service` | 8008 | Financial, occupancy, and operational reports |
| `notification-service` | 8009 | Email, SMS, push notifications (async) |

---

## 4. Shared Infrastructure

### 4.1 Common Library (`shared/`)

All services import from a shared internal package:

```
shared/
├── auth/
│   └── jwt_middleware.py      ← FastAPI dependency for token validation
├── models/
│   └── base_response.py       ← StandardResponse, ErrorResponse schemas
├── exceptions/
│   └── app_exceptions.py      ← DomainException, NotFoundError, AuthError
├── database/
│   └── session.py             ← SQLAlchemy async session factory
└── messaging/
    └── publisher.py           ← RabbitMQ / Redis Streams event publisher
```

### 4.2 Standard API Response

```json
{
  "success": true,
  "data": { ... },
  "meta": { "page": 1, "total": 100 }
}
```

Error:
```json
{
  "success": false,
  "error": {
    "code": "TENANT_NOT_FOUND",
    "message": "Tenant with id 123 not found",
    "details": []
  }
}
```

### 4.3 Database Layout

Each service owns its own PostgreSQL **schema**:

```
Database: bogineni_prop_mgmt
├── schema: auth
├── schema: property
├── schema: tenant
├── schema: application
├── schema: accounting
├── schema: maintenance
├── schema: listing
└── schema: reports
```

Cross-service joins are **not allowed** — services call each other via REST APIs.

### 4.4 Message Queue Events (async)

```
tenant.created          → notification-service (welcome email)
application.approved    → tenant-service (create tenant profile)
rent.payment_received   → accounting-service (post to ledger)
maintenance.assigned    → notification-service (vendor email)
lease.expiring_soon     → notification-service (renewal reminder)
```

---

## 5. Tech Stack Per Service

```
Runtime:       Python 3.11
Framework:     FastAPI
ORM:           SQLAlchemy 2.0 (async)
Migrations:    Alembic
Validation:    Pydantic v2
Auth:          python-jose (JWT), passlib (bcrypt)
DB Driver:     asyncpg (PostgreSQL)
HTTP Client:   httpx (inter-service calls)
Queue:         aio-pika (RabbitMQ) or redis-py (Redis Streams)
Testing:       pytest + pytest-asyncio + httpx AsyncClient
Type Check:    mypy (strict)
Linting:       ruff
Containerize:  Docker + docker-compose
```

---

## 6. Per-Service Folder Structure

Every service follows the same layout:

```
{service-name}/
├── app/
│   ├── domain/
│   │   ├── entities/          ← Pure Python dataclasses / Pydantic models
│   │   ├── repositories/      ← Abstract interfaces (ABC)
│   │   └── exceptions.py      ← Domain-specific exceptions
│   │
│   ├── application/
│   │   └── use_cases/         ← One file per use case
│   │
│   ├── infrastructure/
│   │   ├── db/
│   │   │   ├── models.py      ← SQLAlchemy ORM models
│   │   │   └── repositories/  ← Concrete repository implementations
│   │   ├── sql/               ← .sql files for stored procedures
│   │   └── external/          ← Third-party API clients (Stripe, Twilio, etc.)
│   │
│   └── interfaces/
│       ├── api/
│       │   ├── v1/
│       │   │   └── routes/    ← FastAPI routers
│       │   └── dependencies.py ← FastAPI Depends() definitions
│       └── schemas/
│           ├── requests/       ← Pydantic request schemas
│           └── responses/      ← Pydantic response schemas
│
├── migrations/                ← Alembic revisions
│   ├── env.py
│   └── versions/
├── tests/
│   ├── unit/                  ← Use case tests with mocked repos
│   └── integration/           ← Repo tests against real test DB
├── Dockerfile
├── alembic.ini
├── pyproject.toml
└── main.py
```

---

## 7. Deployment

```
API Gateway (Nginx / Kong)
        │
        ├── /auth/*        → auth-service:8001
        ├── /properties/*  → property-service:8002
        ├── /tenants/*     → tenant-service:8003
        ├── /applications/*→ application-service:8004
        ├── /accounting/*  → accounting-service:8005
        ├── /maintenance/* → maintenance-service:8006
        ├── /listings/*    → listing-service:8007
        ├── /reports/*     → reports-service:8008
        └── (internal)     → notification-service:8009
```

All services run as Docker containers orchestrated via `docker-compose` (dev) or Kubernetes (prod).

---

## 8. Security

- JWT signed with RS256 (asymmetric keys)
- All inter-service calls include a service-level API key in `X-Service-Key` header
- No service exposes its database outside the Docker network
- All secrets in environment variables — never in code
- Rate limiting at API gateway level
- HTTPS enforced end-to-end
