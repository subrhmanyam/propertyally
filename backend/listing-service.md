# Listing Service
**Port:** 8007 | **Schema:** `listing` | **Prefix:** `/api/v1/listings`

---

## Responsibility

Powers the **public-facing listing website** for Bogineni Group — showing available rental units to prospective tenants. Aggregates data from property-service (unit details, photos) and maintains listing-specific content (marketing descriptions, virtual tour URLs, pricing). Also serves as the contact/inquiry entry point that routes to application-service.

---

## Domain Entities

```python
@dataclass
class Listing:
    id: UUID
    unit_id: UUID           # References property.units.id
    property_id: UUID
    title: str              # Marketing headline
    description: str        # Public marketing copy
    rent_amount: Decimal
    deposit_amount: Decimal
    available_date: date
    bedrooms: int
    bathrooms: Decimal
    square_feet: Optional[int]
    amenities: list[str]
    photos: list[str]       # S3 URLs
    virtual_tour_url: Optional[str]
    pet_policy: PetPolicy   # NONE, CATS_ONLY, DOGS_SMALL, DOGS_ALL, ALL_PETS
    utilities_included: list[str]   # WATER, GAS, ELECTRIC, INTERNET
    status: ListingStatus   # ACTIVE, PAUSED, RENTED
    views_count: int
    created_at: datetime
    updated_at: datetime

@dataclass
class Inquiry:
    id: UUID
    listing_id: UUID
    inquirer_name: str
    inquirer_email: str
    inquirer_phone: Optional[str]
    message: str
    preferred_move_in: Optional[date]
    status: InquiryStatus   # NEW, RESPONDED, CONVERTED, CLOSED
    created_at: datetime
```

---

## Use Cases

| Use Case | Description |
|---|---|
| `CreateListing` | Manager publishes a vacant unit as a listing |
| `UpdateListing` | Edit listing details and marketing copy |
| `PauseListing` | Temporarily hide from public (not rented yet) |
| `MarkListingRented` | Deactivate listing when unit is occupied |
| `GetPublicListings` | Public endpoint — available listings with search/filter |
| `GetListingDetail` | Public endpoint — full listing detail page |
| `TrackListingView` | Increment view count (anonymous) |
| `SubmitInquiry` | Prospective tenant sends inquiry |
| `RespondToInquiry` | Manager marks inquiry as responded |
| `ConvertInquiryToApplication` | Link inquiry to an application in application-service |
| `GetListingAnalytics` | Views, inquiries, conversion rate per listing |

---

## API Endpoints

### Public (no auth required)
```
GET    /api/v1/listings/public                 → GetPublicListings
GET    /api/v1/listings/public/{id}            → GetListingDetail
POST   /api/v1/listings/public/{id}/view       → TrackListingView (fire-and-forget)
POST   /api/v1/listings/public/{id}/inquire    → SubmitInquiry
```

### Manager (auth required)
```
GET    /api/v1/listings                        → List all listings (manager view)
POST   /api/v1/listings                        → CreateListing
GET    /api/v1/listings/{id}                   → Get listing (manager view with analytics)
PUT    /api/v1/listings/{id}                   → UpdateListing
PATCH  /api/v1/listings/{id}/pause             → PauseListing
PATCH  /api/v1/listings/{id}/rented            → MarkListingRented

GET    /api/v1/listings/{id}/inquiries         → List inquiries for listing
GET    /api/v1/listings/inquiries/{id}         → GetInquiry
PATCH  /api/v1/listings/inquiries/{id}/respond → RespondToInquiry
PATCH  /api/v1/listings/inquiries/{id}/convert → ConvertInquiryToApplication

GET    /api/v1/listings/{id}/analytics         → GetListingAnalytics
```

---

## Database Tables (schema: `listing`)

```sql
CREATE TABLE listing.listings (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    unit_id           UUID UNIQUE NOT NULL,  -- One listing per unit
    property_id       UUID NOT NULL,
    title             VARCHAR(255) NOT NULL,
    description       TEXT,
    rent_amount       NUMERIC(10,2) NOT NULL,
    deposit_amount    NUMERIC(10,2) DEFAULT 0,
    available_date    DATE NOT NULL,
    bedrooms          SMALLINT NOT NULL DEFAULT 0,
    bathrooms         NUMERIC(3,1) NOT NULL DEFAULT 1,
    square_feet       INTEGER,
    amenities         TEXT[] DEFAULT '{}',
    photos            TEXT[] DEFAULT '{}',
    virtual_tour_url  TEXT,
    pet_policy        VARCHAR(30) DEFAULT 'NONE',
    utilities_included TEXT[] DEFAULT '{}',
    status            VARCHAR(20) DEFAULT 'ACTIVE',
    views_count       INTEGER DEFAULT 0,
    created_at        TIMESTAMPTZ DEFAULT now(),
    updated_at        TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE listing.inquiries (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id          UUID REFERENCES listing.listings(id) ON DELETE CASCADE,
    inquirer_name       VARCHAR(255) NOT NULL,
    inquirer_email      VARCHAR(255) NOT NULL,
    inquirer_phone      VARCHAR(30),
    message             TEXT NOT NULL,
    preferred_move_in   DATE,
    status              VARCHAR(20) DEFAULT 'NEW',
    application_id      UUID,            -- Set when converted
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_listings_status        ON listing.listings(status);
CREATE INDEX idx_listings_property      ON listing.listings(property_id);
CREATE INDEX idx_listings_available     ON listing.listings(available_date);
CREATE INDEX idx_listings_rent          ON listing.listings(rent_amount);
CREATE INDEX idx_listings_bedrooms      ON listing.listings(bedrooms);
CREATE INDEX idx_inquiries_listing      ON listing.inquiries(listing_id);
CREATE INDEX idx_inquiries_status       ON listing.inquiries(status);
```

---

## Public Search & Filtering

The `GetPublicListings` endpoint supports:

```
?bedrooms=2
?min_rent=1000&max_rent=2000
?city=Brockton
?pet_policy=ALL_PETS
?available_from=2024-05-01
?sort=rent_asc|rent_desc|newest|available_soon
?page=1&per_page=20
```

---

## Events Consumed

| Event | Action |
|---|---|
| `unit.status_changed` to OCCUPIED | Auto-call `MarkListingRented` |
| `unit.status_changed` to VACANT | Create a listing stub for manager to complete |
| `property.deleted` | Deactivate all listings for that property |

## Events Published

| Event | Consumers |
|---|---|
| `inquiry.submitted` | notification-service (alert manager, confirmation to inquirer) |
