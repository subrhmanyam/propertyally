# Property Service
**Port:** 8002 | **Schema:** `property` | **Prefix:** `/api/v1/properties`

---

## Responsibility

Manages the full property and unit lifecycle — creation, editing, photo management, amenities, unit configuration, and occupancy status. This is the central domain model that all other services reference by `property_id` and `unit_id`.

---

## Domain Entities

```python
@dataclass
class Property:
    id: UUID
    owner_id: UUID          # References auth.users.id
    name: str
    address: Address
    property_type: PropertyType   # SINGLE_FAMILY, MULTI_FAMILY, APARTMENT, COMMERCIAL
    year_built: Optional[int]
    total_units: int
    amenities: list[str]
    photos: list[str]       # S3 URLs
    is_active: bool
    created_at: datetime

@dataclass
class Unit:
    id: UUID
    property_id: UUID
    unit_number: str
    bedrooms: int
    bathrooms: Decimal
    square_feet: Optional[int]
    rent_amount: Decimal
    deposit_amount: Decimal
    status: UnitStatus      # VACANT, OCCUPIED, UNDER_MAINTENANCE, RESERVED
    floor: Optional[int]
    features: list[str]
    photos: list[str]

@dataclass
class Address:
    street: str
    city: str
    state: str
    zip_code: str
    country: str = "US"
```

---

## Use Cases

| Use Case | Description |
|---|---|
| `CreateProperty` | Add new property with address validation |
| `UpdateProperty` | Edit property details, amenities |
| `DeleteProperty` | Soft delete — marks is_active=false |
| `ListProperties` | Paginated list with filters (owner, city, type, status) |
| `GetProperty` | Single property with all units |
| `UploadPropertyPhotos` | Upload to S3, store URLs |
| `CreateUnit` | Add unit to existing property |
| `UpdateUnit` | Edit unit details, rent amount |
| `UpdateUnitStatus` | Change occupancy status (called by tenant/accounting services) |
| `GetOccupancySummary` | Total units, occupied, vacant counts per property |

---

## API Endpoints

```
GET    /api/v1/properties                     → ListProperties
POST   /api/v1/properties                     → CreateProperty
GET    /api/v1/properties/{id}                → GetProperty
PUT    /api/v1/properties/{id}                → UpdateProperty
DELETE /api/v1/properties/{id}                → DeleteProperty (soft)
POST   /api/v1/properties/{id}/photos         → UploadPropertyPhotos

GET    /api/v1/properties/{id}/units          → List units for property
POST   /api/v1/properties/{id}/units          → CreateUnit
GET    /api/v1/properties/{id}/units/{uid}    → GetUnit
PUT    /api/v1/properties/{id}/units/{uid}    → UpdateUnit
PATCH  /api/v1/properties/{id}/units/{uid}/status → UpdateUnitStatus

GET    /api/v1/properties/{id}/occupancy      → GetOccupancySummary
```

---

## Database Tables (schema: `property`)

```sql
CREATE TABLE property.properties (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id      UUID NOT NULL,   -- FK to auth.users (cross-schema ref, enforced by app)
    name          VARCHAR(255) NOT NULL,
    street        VARCHAR(255) NOT NULL,
    city          VARCHAR(100) NOT NULL,
    state         VARCHAR(50)  NOT NULL,
    zip_code      VARCHAR(20)  NOT NULL,
    country       VARCHAR(50)  DEFAULT 'US',
    property_type VARCHAR(50)  NOT NULL,
    year_built    SMALLINT,
    amenities     TEXT[]       DEFAULT '{}',
    photos        TEXT[]       DEFAULT '{}',
    is_active     BOOLEAN      DEFAULT true,
    created_at    TIMESTAMPTZ  DEFAULT now(),
    updated_at    TIMESTAMPTZ  DEFAULT now()
);

CREATE TABLE property.units (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id    UUID REFERENCES property.properties(id) ON DELETE CASCADE,
    unit_number    VARCHAR(50)   NOT NULL,
    bedrooms       SMALLINT      NOT NULL DEFAULT 0,
    bathrooms      NUMERIC(3,1)  NOT NULL DEFAULT 1,
    square_feet    INTEGER,
    rent_amount    NUMERIC(10,2) NOT NULL,
    deposit_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    status         VARCHAR(30)   NOT NULL DEFAULT 'VACANT',
    floor          SMALLINT,
    features       TEXT[]        DEFAULT '{}',
    photos         TEXT[]        DEFAULT '{}',
    created_at     TIMESTAMPTZ   DEFAULT now(),
    updated_at     TIMESTAMPTZ   DEFAULT now(),
    UNIQUE(property_id, unit_number)
);

-- Indexes
CREATE INDEX idx_properties_owner ON property.properties(owner_id);
CREATE INDEX idx_properties_city  ON property.properties(city);
CREATE INDEX idx_units_property   ON property.units(property_id);
CREATE INDEX idx_units_status     ON property.units(status);
```

---

## Stored Procedures

```sql
-- infrastructure/sql/get_occupancy_summary.sql
-- Returns occupied/vacant/maintenance counts for a property
CREATE OR REPLACE FUNCTION property.get_occupancy_summary(p_property_id UUID)
RETURNS TABLE (
    total_units       INT,
    occupied          INT,
    vacant            INT,
    under_maintenance INT,
    occupancy_rate    NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::INT,
        COUNT(*) FILTER (WHERE status = 'OCCUPIED')::INT,
        COUNT(*) FILTER (WHERE status = 'VACANT')::INT,
        COUNT(*) FILTER (WHERE status = 'UNDER_MAINTENANCE')::INT,
        ROUND(
            COUNT(*) FILTER (WHERE status = 'OCCUPIED') * 100.0 / NULLIF(COUNT(*), 0),
        2)
    FROM property.units
    WHERE property_id = p_property_id;
END;
$$ LANGUAGE plpgsql;
```

---

## Alembic Migrations

```
migrations/versions/
├── 001_create_properties_table.py
├── 002_create_units_table.py
├── 003_add_occupancy_summary_function.py
└── 004_add_property_indexes.py
```

---

## Events Published

| Event | Trigger | Consumers |
|---|---|---|
| `property.created` | New property added | listing-service |
| `unit.status_changed` | Unit status updated | listing-service, reports-service |
| `property.deleted` | Property soft-deleted | listing-service |
