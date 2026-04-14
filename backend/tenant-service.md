# Tenant Service
**Port:** 8003 | **Schema:** `tenant` | **Prefix:** `/api/v1/tenants`

---

## Responsibility

Manages tenant profiles, lease agreements, tenant screening workflows, and document storage. A tenant is linked to a unit (from property-service) and a user account (from auth-service). Screening integrates with third-party credit/background check providers.

---

## Domain Entities

```python
@dataclass
class Tenant:
    id: UUID
    user_id: UUID           # References auth.users.id
    unit_id: UUID           # References property.units.id
    property_id: UUID
    first_name: str
    last_name: str
    email: str
    phone: str
    date_of_birth: date
    ssn_last_four: str      # Stored encrypted
    emergency_contact: EmergencyContact
    move_in_date: date
    move_out_date: Optional[date]
    status: TenantStatus    # ACTIVE, PAST, EVICTED

@dataclass
class Lease:
    id: UUID
    tenant_id: UUID
    unit_id: UUID
    start_date: date
    end_date: date
    monthly_rent: Decimal
    deposit_paid: Decimal
    lease_document_url: str  # S3 URL
    status: LeaseStatus      # DRAFT, ACTIVE, EXPIRED, TERMINATED
    signed_at: Optional[datetime]

@dataclass
class ScreeningResult:
    id: UUID
    applicant_id: UUID      # References application-service
    credit_score: Optional[int]
    credit_check_status: CheckStatus   # PASSED, FAILED, PENDING
    background_check_status: CheckStatus
    eviction_history: bool
    income_verified: bool
    recommendation: ScreeningRecommendation  # APPROVE, DENY, REVIEW
    completed_at: Optional[datetime]
    report_url: Optional[str]
```

---

## Use Cases

| Use Case | Description |
|---|---|
| `CreateTenant` | Create tenant profile after application approval |
| `UpdateTenant` | Edit personal info, emergency contact |
| `GetTenant` | Full tenant profile with lease info |
| `ListTenants` | Paginated, filterable by property/status |
| `InitiateScreening` | Call third-party API, create screening record |
| `UpdateScreeningResult` | Webhook from screening provider |
| `CreateLease` | Draft lease with terms |
| `ActivateLease` | Mark lease active after signing |
| `TerminateLease` | End lease, update unit status via property-service |
| `UploadDocument` | Attach documents (ID, references, etc.) |
| `GetTenantHistory` | All past leases and screening for a tenant |

---

## API Endpoints

```
GET    /api/v1/tenants                        → ListTenants
POST   /api/v1/tenants                        → CreateTenant
GET    /api/v1/tenants/{id}                   → GetTenant
PUT    /api/v1/tenants/{id}                   → UpdateTenant

GET    /api/v1/tenants/{id}/lease             → Current lease
POST   /api/v1/tenants/{id}/lease             → CreateLease
PATCH  /api/v1/tenants/{id}/lease/activate    → ActivateLease
PATCH  /api/v1/tenants/{id}/lease/terminate   → TerminateLease

POST   /api/v1/tenants/{id}/screening         → InitiateScreening
GET    /api/v1/tenants/{id}/screening         → GetScreeningResult

POST   /api/v1/tenants/{id}/documents         → UploadDocument
GET    /api/v1/tenants/{id}/documents         → List documents

POST   /api/v1/tenants/screening/webhook      → UpdateScreeningResult (provider callback)
```

---

## Database Tables (schema: `tenant`)

```sql
CREATE TABLE tenant.tenants (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID UNIQUE NOT NULL,
    unit_id             UUID NOT NULL,
    property_id         UUID NOT NULL,
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100) NOT NULL,
    email               VARCHAR(255) NOT NULL,
    phone               VARCHAR(30),
    date_of_birth       DATE,
    ssn_last_four_enc   BYTEA,          -- Encrypted at rest
    emergency_contact   JSONB,
    move_in_date        DATE,
    move_out_date       DATE,
    status              VARCHAR(20) DEFAULT 'ACTIVE',
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE tenant.leases (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID REFERENCES tenant.tenants(id),
    unit_id             UUID NOT NULL,
    start_date          DATE NOT NULL,
    end_date            DATE NOT NULL,
    monthly_rent        NUMERIC(10,2) NOT NULL,
    deposit_paid        NUMERIC(10,2) DEFAULT 0,
    lease_document_url  TEXT,
    status              VARCHAR(20) DEFAULT 'DRAFT',
    signed_at           TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE tenant.screening_results (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    applicant_id            UUID NOT NULL,
    external_report_id      VARCHAR(255),    -- ID from screening provider
    credit_score            SMALLINT,
    credit_check_status     VARCHAR(20),
    background_check_status VARCHAR(20),
    eviction_history        BOOLEAN DEFAULT false,
    income_verified         BOOLEAN DEFAULT false,
    recommendation          VARCHAR(20),
    report_url              TEXT,
    completed_at            TIMESTAMPTZ,
    created_at              TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE tenant.documents (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id    UUID REFERENCES tenant.tenants(id) ON DELETE CASCADE,
    document_type VARCHAR(50),  -- ID, LEASE, REFERENCE, OTHER
    file_url     TEXT NOT NULL,
    file_name    VARCHAR(255),
    uploaded_at  TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_tenants_unit     ON tenant.tenants(unit_id);
CREATE INDEX idx_tenants_status   ON tenant.tenants(status);
CREATE INDEX idx_leases_tenant    ON tenant.leases(tenant_id);
CREATE INDEX idx_leases_status    ON tenant.leases(status);
CREATE INDEX idx_leases_end_date  ON tenant.leases(end_date);  -- For expiry reminders
```

---

## Stored Procedures

```sql
-- infrastructure/sql/get_expiring_leases.sql
-- Called by notification-service scheduler
CREATE OR REPLACE FUNCTION tenant.get_expiring_leases(days_ahead INT)
RETURNS TABLE (
    lease_id    UUID,
    tenant_id   UUID,
    tenant_email VARCHAR,
    unit_id     UUID,
    end_date    DATE,
    days_until_expiry INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        l.id,
        l.tenant_id,
        t.email,
        l.unit_id,
        l.end_date,
        (l.end_date - CURRENT_DATE)::INT
    FROM tenant.leases l
    JOIN tenant.tenants t ON t.id = l.tenant_id
    WHERE l.status = 'ACTIVE'
      AND l.end_date BETWEEN CURRENT_DATE AND CURRENT_DATE + days_ahead;
END;
$$ LANGUAGE plpgsql;
```

---

## Third-Party Integrations

- **TransUnion SmartMove** or **Checkr** — credit and background screening API
- **AWS S3** — document and lease file storage

---

## Events Published

| Event | Consumers |
|---|---|
| `tenant.created` | notification-service (welcome), accounting-service (create rent schedule) |
| `lease.activated` | property-service (set unit OCCUPIED), accounting-service |
| `lease.terminated` | property-service (set unit VACANT), notification-service |
| `lease.expiring_soon` | notification-service (renewal reminder) |
| `screening.completed` | notification-service (result email to manager) |

---

## Events Consumed

| Event | Action |
|---|---|
| `application.approved` | Trigger `CreateTenant` use case |
