# Maintenance Service
**Port:** 8006 | **Schema:** `maintenance` | **Prefix:** `/api/v1/maintenance`

---

## Responsibility

Manages the full lifecycle of maintenance requests — submission by tenants, assignment to vendors or maintenance staff, status tracking, work order management, cost logging, and completion sign-off.

---

## Domain Entities

```python
@dataclass
class MaintenanceRequest:
    id: UUID
    unit_id: UUID
    property_id: UUID
    tenant_id: Optional[UUID]    # Null if submitted by manager
    title: str
    description: str
    category: MaintenanceCategory  # PLUMBING, ELECTRICAL, HVAC, APPLIANCE, STRUCTURAL, OTHER
    priority: Priority             # LOW, MEDIUM, HIGH, EMERGENCY
    status: RequestStatus          # OPEN, ASSIGNED, IN_PROGRESS, PENDING_APPROVAL, COMPLETED, CANCELLED
    photos: list[str]              # S3 URLs uploaded by tenant
    created_at: datetime
    updated_at: datetime

@dataclass
class WorkOrder:
    id: UUID
    request_id: UUID
    vendor_id: Optional[UUID]
    assigned_staff_id: Optional[UUID]
    scheduled_date: Optional[date]
    estimated_cost: Optional[Decimal]
    actual_cost: Optional[Decimal]
    work_notes: str
    completion_photos: list[str]
    completed_at: Optional[datetime]
    approved_by: Optional[UUID]      # Manager who approved completion

@dataclass
class Vendor:
    id: UUID
    name: str
    contact_name: str
    email: str
    phone: str
    trade: str          # Plumber, Electrician, HVAC Tech, General
    is_active: bool
    rating: Optional[Decimal]
```

---

## Use Cases

| Use Case | Description |
|---|---|
| `SubmitRequest` | Tenant or manager creates a maintenance request |
| `UpdateRequestStatus` | Manager updates status |
| `AssignRequest` | Assign to vendor or staff, create work order |
| `UpdateWorkOrder` | Add notes, scheduled date, cost estimate |
| `CompleteWorkOrder` | Mark work done, upload completion photos |
| `ApproveCompletion` | Manager signs off on completed work |
| `CancelRequest` | Cancel an open request |
| `ListRequests` | Filter by property, status, priority, date |
| `GetRequest` | Full request + work order detail |
| `AddVendor` | Register a vendor |
| `ListVendors` | Get available vendors by trade |
| `GetMaintenanceCostSummary` | Total maintenance spend for a property/period |

---

## API Endpoints

```
GET    /api/v1/maintenance                         → ListRequests
POST   /api/v1/maintenance                         → SubmitRequest
GET    /api/v1/maintenance/{id}                    → GetRequest
PATCH  /api/v1/maintenance/{id}/status             → UpdateRequestStatus
PATCH  /api/v1/maintenance/{id}/cancel             → CancelRequest

POST   /api/v1/maintenance/{id}/assign             → AssignRequest (creates WorkOrder)
GET    /api/v1/maintenance/{id}/work-order         → Get WorkOrder
PUT    /api/v1/maintenance/{id}/work-order         → UpdateWorkOrder
POST   /api/v1/maintenance/{id}/work-order/complete → CompleteWorkOrder
POST   /api/v1/maintenance/{id}/work-order/approve  → ApproveCompletion

GET    /api/v1/maintenance/vendors                 → ListVendors
POST   /api/v1/maintenance/vendors                 → AddVendor
PUT    /api/v1/maintenance/vendors/{id}            → UpdateVendor

GET    /api/v1/maintenance/summary                 → GetMaintenanceCostSummary
```

---

## Database Tables (schema: `maintenance`)

```sql
CREATE TABLE maintenance.requests (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    unit_id     UUID NOT NULL,
    property_id UUID NOT NULL,
    tenant_id   UUID,
    title       VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    category    VARCHAR(50)  NOT NULL,
    priority    VARCHAR(20)  NOT NULL DEFAULT 'MEDIUM',
    status      VARCHAR(30)  NOT NULL DEFAULT 'OPEN',
    photos      TEXT[]       DEFAULT '{}',
    created_at  TIMESTAMPTZ  DEFAULT now(),
    updated_at  TIMESTAMPTZ  DEFAULT now()
);

CREATE TABLE maintenance.work_orders (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id          UUID REFERENCES maintenance.requests(id) ON DELETE CASCADE,
    vendor_id           UUID,
    assigned_staff_id   UUID,
    scheduled_date      DATE,
    estimated_cost      NUMERIC(10,2),
    actual_cost         NUMERIC(10,2),
    work_notes          TEXT,
    completion_photos   TEXT[] DEFAULT '{}',
    completed_at        TIMESTAMPTZ,
    approved_by         UUID,
    approved_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE maintenance.vendors (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name         VARCHAR(255) NOT NULL,
    contact_name VARCHAR(255),
    email        VARCHAR(255),
    phone        VARCHAR(30),
    trade        VARCHAR(100),
    is_active    BOOLEAN DEFAULT true,
    rating       NUMERIC(3,2),
    created_at   TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_requests_property ON maintenance.requests(property_id);
CREATE INDEX idx_requests_status   ON maintenance.requests(status);
CREATE INDEX idx_requests_priority ON maintenance.requests(priority);
CREATE INDEX idx_requests_tenant   ON maintenance.requests(tenant_id);
CREATE INDEX idx_work_orders_req   ON maintenance.work_orders(request_id);
CREATE INDEX idx_work_orders_vendor ON maintenance.work_orders(vendor_id);
```

---

## Priority & SLA Rules

| Priority | Response Target | Completion Target |
|---|---|---|
| EMERGENCY | 1 hour | 24 hours |
| HIGH | 4 hours | 3 days |
| MEDIUM | 24 hours | 7 days |
| LOW | 48 hours | 14 days |

SLA breach detection runs as a scheduled job in the service and publishes events to notification-service.

---

## Events Published

| Event | Consumers |
|---|---|
| `maintenance.request_submitted` | notification-service (confirmation to tenant, alert to manager) |
| `maintenance.assigned` | notification-service (email to vendor/staff) |
| `maintenance.completed` | notification-service (notify tenant, manager for approval) |
| `maintenance.approved` | accounting-service (log actual cost as expense) |
| `maintenance.sla_breached` | notification-service (escalation alert) |

---

## Events Consumed

None — this service is a leaf in the event graph.
