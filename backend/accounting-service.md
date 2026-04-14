# Accounting Service
**Port:** 8005 | **Schema:** `accounting` | **Prefix:** `/api/v1/accounting`

---

## Responsibility

Manages all financial operations: rent roll generation, payment recording, expense tracking, invoice creation, double-entry ledger posting, and financial summaries. Complex monetary operations (ledger postings, rent roll calculations) are handled by PostgreSQL stored procedures to ensure atomicity.

---

## Domain Entities

```python
@dataclass
class RentCharge:
    id: UUID
    tenant_id: UUID
    unit_id: UUID
    property_id: UUID
    amount: Decimal
    due_date: date
    period_month: int   # e.g. 4 = April
    period_year: int
    status: ChargeStatus   # PENDING, PAID, PARTIAL, OVERDUE, WAIVED

@dataclass
class Payment:
    id: UUID
    rent_charge_id: UUID
    tenant_id: UUID
    amount: Decimal
    payment_date: date
    payment_method: PaymentMethod   # ACH, CREDIT_CARD, CHECK, CASH
    transaction_ref: str            # External payment processor ref
    status: PaymentStatus           # PENDING, COMPLETED, FAILED, REFUNDED

@dataclass
class Expense:
    id: UUID
    property_id: UUID
    category: ExpenseCategory  # MAINTENANCE, INSURANCE, TAX, UTILITY, OTHER
    description: str
    amount: Decimal
    expense_date: date
    vendor_name: Optional[str]
    receipt_url: Optional[str]

@dataclass
class LedgerEntry:
    id: UUID
    property_id: UUID
    entry_date: date
    description: str
    debit: Decimal
    credit: Decimal
    balance: Decimal
    reference_id: UUID       # ID of payment, expense, or charge
    reference_type: str      # PAYMENT, EXPENSE, CHARGE
```

---

## Use Cases

| Use Case | Description |
|---|---|
| `GenerateMonthlyRentCharges` | Bulk create rent charges for all active leases for a given month |
| `RecordPayment` | Post a tenant payment, mark charge paid/partial, post to ledger |
| `MarkChargeOverdue` | Called by scheduler — marks pending charges past due date as OVERDUE |
| `CreateExpense` | Record an expense, post debit to ledger |
| `GetRentRoll` | Rent roll table: all units, tenants, charges, payment status |
| `GetLedger` | Date-range ledger for a property |
| `GetFinancialSummary` | Revenue, expenses, net income for date range |
| `CreateInvoice` | Generate invoice PDF for tenant |
| `ProcessRefund` | Reverse a payment entry, update ledger |
| `WaiveCharge` | Manager waives a charge (with reason) |

---

## API Endpoints

```
GET    /api/v1/accounting/rent-roll                     → GetRentRoll (filterable by property, month)
POST   /api/v1/accounting/rent-charges/generate         → GenerateMonthlyRentCharges
GET    /api/v1/accounting/rent-charges/{id}             → Get single charge
PATCH  /api/v1/accounting/rent-charges/{id}/waive       → WaiveCharge

POST   /api/v1/accounting/payments                      → RecordPayment
GET    /api/v1/accounting/payments/{id}                 → Get payment
POST   /api/v1/accounting/payments/{id}/refund          → ProcessRefund

POST   /api/v1/accounting/expenses                      → CreateExpense
GET    /api/v1/accounting/expenses                      → List expenses (by property, date range)
PUT    /api/v1/accounting/expenses/{id}                 → UpdateExpense
DELETE /api/v1/accounting/expenses/{id}                 → DeleteExpense

GET    /api/v1/accounting/ledger                        → GetLedger (property_id, from, to)
GET    /api/v1/accounting/summary                       → GetFinancialSummary

POST   /api/v1/accounting/invoices                      → CreateInvoice
GET    /api/v1/accounting/invoices/{id}                 → Get invoice PDF URL

POST   /api/v1/accounting/webhook/payment               → Payment processor webhook
```

---

## Database Tables (schema: `accounting`)

```sql
CREATE TABLE accounting.rent_charges (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id    UUID NOT NULL,
    unit_id      UUID NOT NULL,
    property_id  UUID NOT NULL,
    amount       NUMERIC(10,2) NOT NULL,
    due_date     DATE NOT NULL,
    period_month SMALLINT NOT NULL,
    period_year  SMALLINT NOT NULL,
    status       VARCHAR(20) DEFAULT 'PENDING',
    waived_by    UUID,
    waived_at    TIMESTAMPTZ,
    waive_reason TEXT,
    created_at   TIMESTAMPTZ DEFAULT now(),
    UNIQUE(tenant_id, period_month, period_year)
);

CREATE TABLE accounting.payments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rent_charge_id  UUID REFERENCES accounting.rent_charges(id),
    tenant_id       UUID NOT NULL,
    amount          NUMERIC(10,2) NOT NULL,
    payment_date    DATE NOT NULL,
    payment_method  VARCHAR(30),
    transaction_ref VARCHAR(255),
    status          VARCHAR(20) DEFAULT 'COMPLETED',
    refunded_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE accounting.expenses (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id  UUID NOT NULL,
    category     VARCHAR(50) NOT NULL,
    description  TEXT NOT NULL,
    amount       NUMERIC(10,2) NOT NULL,
    expense_date DATE NOT NULL,
    vendor_name  VARCHAR(255),
    receipt_url  TEXT,
    created_at   TIMESTAMPTZ DEFAULT now(),
    updated_at   TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE accounting.ledger (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    property_id    UUID NOT NULL,
    entry_date     DATE NOT NULL,
    description    TEXT NOT NULL,
    debit          NUMERIC(10,2) DEFAULT 0,
    credit         NUMERIC(10,2) DEFAULT 0,
    balance        NUMERIC(10,2) NOT NULL,
    reference_id   UUID,
    reference_type VARCHAR(30),
    created_at     TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_charges_property ON accounting.rent_charges(property_id);
CREATE INDEX idx_charges_tenant   ON accounting.rent_charges(tenant_id);
CREATE INDEX idx_charges_status   ON accounting.rent_charges(status);
CREATE INDEX idx_charges_due_date ON accounting.rent_charges(due_date);
CREATE INDEX idx_payments_charge  ON accounting.payments(rent_charge_id);
CREATE INDEX idx_ledger_property  ON accounting.ledger(property_id, entry_date);
CREATE INDEX idx_expenses_property ON accounting.expenses(property_id, expense_date);
```

---

## Stored Procedures

```sql
-- infrastructure/sql/record_payment_and_post_ledger.sql
-- Atomically records a payment, updates charge status, and posts to ledger
CREATE OR REPLACE FUNCTION accounting.record_payment_and_post_ledger(
    p_charge_id     UUID,
    p_tenant_id     UUID,
    p_property_id   UUID,
    p_amount        NUMERIC,
    p_method        VARCHAR,
    p_ref           VARCHAR,
    p_description   TEXT
) RETURNS UUID AS $$
DECLARE
    v_payment_id  UUID;
    v_prev_balance NUMERIC;
BEGIN
    -- Insert payment
    INSERT INTO accounting.payments (rent_charge_id, tenant_id, amount, payment_date, payment_method, transaction_ref)
    VALUES (p_charge_id, p_tenant_id, p_amount, CURRENT_DATE, p_method, p_ref)
    RETURNING id INTO v_payment_id;

    -- Update charge status
    UPDATE accounting.rent_charges
    SET status = CASE
        WHEN (SELECT SUM(amount) FROM accounting.payments WHERE rent_charge_id = p_charge_id) >= amount
            THEN 'PAID'
        ELSE 'PARTIAL'
    END
    WHERE id = p_charge_id;

    -- Get previous ledger balance
    SELECT COALESCE(balance, 0) INTO v_prev_balance
    FROM accounting.ledger
    WHERE property_id = p_property_id
    ORDER BY entry_date DESC, created_at DESC
    LIMIT 1;

    -- Post to ledger (credit = income)
    INSERT INTO accounting.ledger (property_id, entry_date, description, credit, balance, reference_id, reference_type)
    VALUES (p_property_id, CURRENT_DATE, p_description, p_amount, v_prev_balance + p_amount, v_payment_id, 'PAYMENT');

    RETURN v_payment_id;
END;
$$ LANGUAGE plpgsql;

-- infrastructure/sql/get_financial_summary.sql
CREATE OR REPLACE FUNCTION accounting.get_financial_summary(
    p_property_id UUID,
    p_from DATE,
    p_to   DATE
) RETURNS TABLE (
    total_revenue  NUMERIC,
    total_expenses NUMERIC,
    net_income     NUMERIC,
    outstanding    NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(SUM(p.amount) FILTER (WHERE p.status = 'COMPLETED'), 0),
        COALESCE(SUM(e.amount), 0),
        COALESCE(SUM(p.amount) FILTER (WHERE p.status = 'COMPLETED'), 0) - COALESCE(SUM(e.amount), 0),
        COALESCE(SUM(rc.amount) FILTER (WHERE rc.status IN ('PENDING', 'OVERDUE', 'PARTIAL')), 0)
    FROM accounting.rent_charges rc
    LEFT JOIN accounting.payments p ON p.rent_charge_id = rc.id AND p.payment_date BETWEEN p_from AND p_to
    LEFT JOIN accounting.expenses e ON e.property_id = p_property_id AND e.expense_date BETWEEN p_from AND p_to
    WHERE rc.property_id = p_property_id
      AND rc.due_date BETWEEN p_from AND p_to;
END;
$$ LANGUAGE plpgsql;
```

---

## Events Published

| Event | Consumers |
|---|---|
| `rent.payment_received` | notification-service (receipt to tenant) |
| `rent.charge_overdue` | notification-service (overdue notice) |
| `rent.charges_generated` | notification-service (monthly invoice) |

## Events Consumed

| Event | Action |
|---|---|
| `lease.activated` | Schedule monthly rent charges for lease term |
| `lease.terminated` | Stop future rent charge generation |

---

## External Integrations

- **Stripe** or **Dwolla** — ACH and credit card payment processing
- **AWS S3** — Invoice PDF storage
