# Reports Service
**Port:** 8008 | **Schema:** `reports` | **Prefix:** `/api/v1/reports`

---

## Responsibility

Generates on-demand and scheduled reports by aggregating data across services. Does not own primary data — calls other services' APIs or reads from a dedicated **read replica / reporting database** that is populated via event streams. Supports export to PDF and CSV.

---

## Domain Entities

```python
@dataclass
class ReportRequest:
    id: UUID
    report_type: ReportType
    requested_by: UUID
    parameters: dict         # Varies by report type
    status: ReportStatus     # QUEUED, GENERATING, READY, FAILED
    file_url: Optional[str]  # S3 URL when ready
    generated_at: Optional[datetime]
    created_at: datetime

@dataclass
class ReportType(str, Enum):
    FINANCIAL_SUMMARY    = "FINANCIAL_SUMMARY"
    RENT_ROLL            = "RENT_ROLL"
    OCCUPANCY            = "OCCUPANCY"
    MAINTENANCE_SUMMARY  = "MAINTENANCE_SUMMARY"
    TENANT_LEDGER        = "TENANT_LEDGER"
    EXPENSE_BREAKDOWN    = "EXPENSE_BREAKDOWN"
    INCOME_STATEMENT     = "INCOME_STATEMENT"
```

---

## Report Definitions

### 1. Financial Summary
**Parameters:** `property_id`, `from_date`, `to_date`
**Data sources:** accounting-service (payments, expenses, ledger)
**Output:** Total revenue, total expenses, net income, outstanding rent, month-by-month bar chart

### 2. Rent Roll
**Parameters:** `property_id`, `month`, `year`
**Data sources:** accounting-service (charges), tenant-service (leases), property-service (units)
**Output:** Table — unit, tenant name, lease end date, monthly rent, payment status, balance

### 3. Occupancy Report
**Parameters:** `property_id` or `owner_id`, `from_date`, `to_date`
**Data sources:** property-service (unit statuses), tenant-service (move-in/out dates)
**Output:** Occupancy rate over time, vacant days per unit, turnover rate

### 4. Maintenance Summary
**Parameters:** `property_id`, `from_date`, `to_date`
**Data sources:** maintenance-service (requests, work orders)
**Output:** Total requests by category/priority, average resolution time, total maintenance cost

### 5. Tenant Ledger
**Parameters:** `tenant_id`, `from_date`, `to_date`
**Data sources:** accounting-service (charges, payments)
**Output:** Statement of charges, payments, credits, and balance for a single tenant

### 6. Expense Breakdown
**Parameters:** `property_id`, `from_date`, `to_date`
**Data sources:** accounting-service (expenses)
**Output:** Expenses grouped by category with totals and percentages

### 7. Income Statement (P&L)
**Parameters:** `property_id` or `owner_id`, `year`
**Data sources:** accounting-service (all)
**Output:** Full P&L — revenues and expenses by month, annual totals

---

## Use Cases

| Use Case | Description |
|---|---|
| `RequestReport` | Queue a report for generation |
| `GenerateReport` | Background task: fetch data, build report, upload to S3 |
| `GetReportStatus` | Poll report generation progress |
| `DownloadReport` | Return S3 pre-signed URL for download |
| `ListReports` | List generated reports for a user |
| `ScheduleReport` | Set up recurring auto-generation (monthly rent roll, etc.) |

---

## API Endpoints

```
POST   /api/v1/reports/request              → RequestReport (queues generation)
GET    /api/v1/reports/{id}/status          → GetReportStatus
GET    /api/v1/reports/{id}/download        → DownloadReport (pre-signed URL)
GET    /api/v1/reports                      → ListReports

POST   /api/v1/reports/schedules            → ScheduleReport
GET    /api/v1/reports/schedules            → List scheduled reports
DELETE /api/v1/reports/schedules/{id}       → Remove schedule

# Quick inline endpoints (small datasets, returns JSON directly)
GET    /api/v1/reports/financial-summary    → Financial summary (inline JSON)
GET    /api/v1/reports/occupancy            → Occupancy summary (inline JSON)
```

---

## Database Tables (schema: `reports`)

```sql
CREATE TABLE reports.report_requests (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_type  VARCHAR(50)  NOT NULL,
    requested_by UUID NOT NULL,
    parameters   JSONB NOT NULL,
    status       VARCHAR(20)  DEFAULT 'QUEUED',
    file_url     TEXT,
    error_message TEXT,
    generated_at TIMESTAMPTZ,
    created_at   TIMESTAMPTZ  DEFAULT now()
);

CREATE TABLE reports.schedules (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_type  VARCHAR(50)  NOT NULL,
    owner_id     UUID NOT NULL,
    parameters   JSONB NOT NULL,
    cron_expr    VARCHAR(50)  NOT NULL,   -- e.g. "0 9 1 * *" = 9am on 1st of month
    last_run_at  TIMESTAMPTZ,
    next_run_at  TIMESTAMPTZ,
    is_active    BOOLEAN DEFAULT true,
    created_at   TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_report_requests_user   ON reports.report_requests(requested_by);
CREATE INDEX idx_report_requests_status ON reports.report_requests(status);
CREATE INDEX idx_schedules_next_run     ON reports.schedules(next_run_at) WHERE is_active = true;
```

---

## Background Processing

Report generation is async:
1. `POST /reports/request` creates a DB record with status `QUEUED`
2. A Celery worker (or async background task) picks it up
3. Worker calls relevant service APIs, generates PDF/CSV using `reportlab` (PDF) or `csv` module
4. Uploads file to S3
5. Updates DB record: status → `READY`, `file_url` set
6. Publishes `report.ready` event → notification-service sends email with download link

---

## Events Published

| Event | Consumers |
|---|---|
| `report.ready` | notification-service (email with download link) |
| `report.failed` | notification-service (failure alert) |

---

## External Dependencies

- `accounting-service` — payments, expenses, ledger data
- `tenant-service` — lease and tenant data
- `property-service` — unit and property data
- `maintenance-service` — maintenance request data
- **reportlab** — PDF generation
- **AWS S3** — report file storage
