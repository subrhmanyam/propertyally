# Notification Service
**Port:** 8009 | **Schema:** `notification` | **Prefix:** `/api/v1/notifications`

---

## Responsibility

Handles all outbound communications — email, SMS, and in-app notifications. Does not initiate notifications itself; it listens to domain events from all other services and delivers the appropriate message. Also maintains a notification inbox for in-app alerts.

---

## Domain Entities

```python
@dataclass
class Notification:
    id: UUID
    recipient_id: UUID          # auth.users.id
    type: NotificationType
    channel: NotificationChannel  # IN_APP, EMAIL, SMS
    title: str
    body: str
    metadata: dict              # Additional context (property_id, etc.)
    is_read: bool
    sent_at: Optional[datetime]
    read_at: Optional[datetime]
    status: DeliveryStatus      # PENDING, SENT, FAILED

@dataclass
class NotificationTemplate:
    id: UUID
    event_type: str             # e.g. "rent.charge_overdue"
    channel: NotificationChannel
    subject_template: str       # Jinja2 template
    body_template: str          # Jinja2 template
    is_active: bool
```

---

## Notification Templates

| Event | Channel | Recipient | Template |
|---|---|---|---|
| `tenant.created` | EMAIL | Tenant | Welcome email with portal login |
| `application.submitted` | EMAIL | Applicant | Application received confirmation |
| `application.approved` | EMAIL | Applicant | Application approved, next steps |
| `application.denied` | EMAIL | Applicant | Application denied with reason |
| `rent.charges_generated` | EMAIL | Tenant | Monthly invoice with payment link |
| `rent.payment_received` | EMAIL + IN_APP | Tenant | Payment receipt |
| `rent.charge_overdue` | EMAIL + SMS + IN_APP | Tenant | Overdue notice with amount due |
| `lease.expiring_soon` | EMAIL + IN_APP | Tenant | Lease renewal reminder |
| `lease.terminated` | EMAIL | Tenant | Move-out confirmation |
| `maintenance.request_submitted` | IN_APP | Manager | New maintenance request alert |
| `maintenance.assigned` | EMAIL | Vendor | Work order details |
| `maintenance.completed` | IN_APP | Manager | Ready for approval |
| `inquiry.submitted` | EMAIL + IN_APP | Manager | New property inquiry |
| `report.ready` | EMAIL | Requester | Report ready with download link |
| `screening.completed` | IN_APP | Manager | Screening result summary |

---

## Use Cases

| Use Case | Description |
|---|---|
| `ProcessEvent` | Consume domain event, render template, dispatch to channel |
| `SendEmail` | Deliver via email provider (SendGrid/SES) |
| `SendSMS` | Deliver via Twilio |
| `CreateInAppNotification` | Write to notification inbox |
| `GetInbox` | Return unread/all notifications for a user |
| `MarkRead` | Mark one or all notifications as read |
| `GetUnreadCount` | Badge count for UI |
| `UpdateTemplate` | Manager edits a notification template |
| `TestNotification` | Send a test notification for a template |

---

## API Endpoints

```
# In-app notification inbox (auth required)
GET    /api/v1/notifications              → GetInbox (user's notifications)
GET    /api/v1/notifications/unread-count → GetUnreadCount
PATCH  /api/v1/notifications/{id}/read    → MarkRead
PATCH  /api/v1/notifications/read-all     → Mark all read

# Template management (admin only)
GET    /api/v1/notifications/templates          → List templates
PUT    /api/v1/notifications/templates/{id}     → UpdateTemplate
POST   /api/v1/notifications/templates/{id}/test → TestNotification

# Internal event webhook (service-to-service, not public)
POST   /internal/notifications/dispatch   → ProcessEvent
```

---

## Database Tables (schema: `notification`)

```sql
CREATE TABLE notification.notifications (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID NOT NULL,
    type         VARCHAR(50)  NOT NULL,
    channel      VARCHAR(20)  NOT NULL,
    title        VARCHAR(255) NOT NULL,
    body         TEXT NOT NULL,
    metadata     JSONB DEFAULT '{}',
    is_read      BOOLEAN DEFAULT false,
    sent_at      TIMESTAMPTZ,
    read_at      TIMESTAMPTZ,
    status       VARCHAR(20) DEFAULT 'PENDING',
    created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE notification.templates (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type       VARCHAR(100) UNIQUE NOT NULL,
    channel          VARCHAR(20) NOT NULL,
    subject_template TEXT NOT NULL,
    body_template    TEXT NOT NULL,   -- Jinja2 syntax
    is_active        BOOLEAN DEFAULT true,
    updated_at       TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE notification.delivery_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID REFERENCES notification.notifications(id),
    provider        VARCHAR(50),   -- sendgrid, twilio, in_app
    provider_ref    VARCHAR(255),  -- External message ID
    status          VARCHAR(20),
    error_message   TEXT,
    attempted_at    TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_notifications_recipient ON notification.notifications(recipient_id, is_read);
CREATE INDEX idx_notifications_created   ON notification.notifications(created_at DESC);
CREATE INDEX idx_delivery_log_notif      ON notification.delivery_log(notification_id);
```

---

## Event Consumption

This service subscribes to all domain events from the message queue:

```python
# Subscribed topics / routing keys
SUBSCRIBED_EVENTS = [
    "tenant.created",
    "application.submitted",
    "application.approved",
    "application.denied",
    "rent.charges_generated",
    "rent.payment_received",
    "rent.charge_overdue",
    "lease.expiring_soon",
    "lease.terminated",
    "maintenance.request_submitted",
    "maintenance.assigned",
    "maintenance.completed",
    "inquiry.submitted",
    "report.ready",
    "screening.completed",
]
```

For each event: look up template by `event_type`, render with Jinja2 using event payload, dispatch to configured channel(s).

---

## External Dependencies

- **SendGrid** or **AWS SES** — transactional email delivery
- **Twilio** — SMS delivery
- **RabbitMQ** / **Redis Streams** — event consumption from other services
- **Jinja2** — template rendering
