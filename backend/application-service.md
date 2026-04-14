# Application Service
**Port:** 8004 | **Schema:** `application` | **Prefix:** `/api/v1/applications`

---

## Responsibility

Manages customizable rental application forms and the submission/review workflow. Property managers can design application templates with custom fields. Prospective tenants fill and submit these forms. Approved applications trigger tenant creation in tenant-service.

---

## Domain Entities

```python
@dataclass
class ApplicationTemplate:
    id: UUID
    property_id: UUID
    name: str
    sections: list[FormSection]   # Ordered list of sections
    is_active: bool
    created_by: UUID

@dataclass
class FormSection:
    id: UUID
    title: str
    order: int
    fields: list[FormField]

@dataclass
class FormField:
    id: UUID
    label: str
    field_type: FieldType   # TEXT, NUMBER, DATE, DROPDOWN, CHECKBOX, FILE
    is_required: bool
    options: list[str]      # For DROPDOWN fields
    order: int

@dataclass
class Application:
    id: UUID
    template_id: UUID
    property_id: UUID
    unit_id: Optional[UUID]
    applicant_id: UUID            # References auth.users.id
    applicant_name: str
    applicant_email: str
    responses: dict               # {field_id: value}
    documents: list[str]          # S3 URLs (ID, pay stubs, etc.)
    status: ApplicationStatus     # DRAFT, SUBMITTED, UNDER_REVIEW, SCREENING, APPROVED, DENIED
    reviewer_id: Optional[UUID]
    reviewer_notes: Optional[str]
    submitted_at: Optional[datetime]
    reviewed_at: Optional[datetime]
```

---

## Use Cases

| Use Case | Description |
|---|---|
| `CreateTemplate` | Manager builds a custom application form |
| `UpdateTemplate` | Edit sections and fields |
| `PublishTemplate` | Make template available for applications |
| `GetTemplate` | Return form structure for rendering |
| `StartApplication` | Applicant begins filling a form (creates DRAFT) |
| `SaveDraft` | Auto-save in-progress application |
| `SubmitApplication` | Finalize and submit — triggers review flow |
| `ReviewApplication` | Manager marks as UNDER_REVIEW |
| `InitiateScreening` | Move to SCREENING — calls tenant-service |
| `ApproveApplication` | Approve — triggers tenant creation |
| `DenyApplication` | Deny with reason — notifies applicant |
| `ListApplications` | Filter by property, status, date |
| `GetApplication` | Full application with all responses |

---

## API Endpoints

```
GET    /api/v1/applications/templates                     → List templates
POST   /api/v1/applications/templates                     → CreateTemplate
GET    /api/v1/applications/templates/{id}                → GetTemplate
PUT    /api/v1/applications/templates/{id}                → UpdateTemplate
PATCH  /api/v1/applications/templates/{id}/publish        → PublishTemplate

GET    /api/v1/applications                               → ListApplications
POST   /api/v1/applications                               → StartApplication
GET    /api/v1/applications/{id}                          → GetApplication
PUT    /api/v1/applications/{id}/draft                    → SaveDraft
POST   /api/v1/applications/{id}/submit                   → SubmitApplication
POST   /api/v1/applications/{id}/documents                → Upload supporting docs

PATCH  /api/v1/applications/{id}/review                   → ReviewApplication
PATCH  /api/v1/applications/{id}/screening                → InitiateScreening
PATCH  /api/v1/applications/{id}/approve                  → ApproveApplication
PATCH  /api/v1/applications/{id}/deny                     → DenyApplication
```

---

## Database Tables (schema: `application`)

```sql
CREATE TABLE application.templates (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id UUID NOT NULL,
    name        VARCHAR(255) NOT NULL,
    is_active   BOOLEAN DEFAULT false,
    created_by  UUID NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now(),
    updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE application.form_sections (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id UUID REFERENCES application.templates(id) ON DELETE CASCADE,
    title       VARCHAR(255) NOT NULL,
    order_index SMALLINT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE application.form_fields (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    section_id  UUID REFERENCES application.form_sections(id) ON DELETE CASCADE,
    label       VARCHAR(255) NOT NULL,
    field_type  VARCHAR(30)  NOT NULL,
    is_required BOOLEAN DEFAULT false,
    options     TEXT[]  DEFAULT '{}',
    order_index SMALLINT NOT NULL
);

CREATE TABLE application.applications (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id    UUID REFERENCES application.templates(id),
    property_id    UUID NOT NULL,
    unit_id        UUID,
    applicant_id   UUID NOT NULL,
    applicant_name VARCHAR(255) NOT NULL,
    applicant_email VARCHAR(255) NOT NULL,
    responses      JSONB DEFAULT '{}',
    documents      TEXT[] DEFAULT '{}',
    status         VARCHAR(30) DEFAULT 'DRAFT',
    reviewer_id    UUID,
    reviewer_notes TEXT,
    submitted_at   TIMESTAMPTZ,
    reviewed_at    TIMESTAMPTZ,
    created_at     TIMESTAMPTZ DEFAULT now(),
    updated_at     TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_applications_property  ON application.applications(property_id);
CREATE INDEX idx_applications_applicant ON application.applications(applicant_id);
CREATE INDEX idx_applications_status    ON application.applications(status);
CREATE INDEX idx_templates_property     ON application.templates(property_id);
```

---

## Events Published

| Event | Consumers |
|---|---|
| `application.submitted` | notification-service (confirmation to applicant, alert to manager) |
| `application.approved` | tenant-service (create tenant profile), notification-service |
| `application.denied` | notification-service (denial notice to applicant) |
| `application.screening_initiated` | tenant-service (run screening) |

---

## Events Consumed

| Event | Action |
|---|---|
| `screening.completed` | Update application status based on result |
