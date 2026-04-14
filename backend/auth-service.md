# Auth Service
**Port:** 8001 | **Schema:** `auth` | **Prefix:** `/api/v1/auth`

---

## Responsibility

Handles all identity concerns: registration, login, JWT issuance/refresh, password management, role-based access control (RBAC), and session management. Every other service delegates token validation to this service's shared middleware.

---

## Roles

| Role | Access |
|---|---|
| `super_admin` | Full platform access |
| `property_manager` | Manage properties, tenants, accounting |
| `landlord` | Own properties only |
| `maintenance_staff` | View and update maintenance requests |
| `tenant` | Own profile, submit requests, pay rent |
| `applicant` | Submit rental applications only |

---

## Domain Entities

```python
# domain/entities/user.py
@dataclass
class User:
    id: UUID
    email: str
    full_name: str
    role: UserRole
    is_active: bool
    created_at: datetime
    last_login: Optional[datetime]

# domain/entities/token.py
@dataclass
class TokenPair:
    access_token: str   # JWT, 15min TTL
    refresh_token: str  # Opaque, 30d TTL
    token_type: str = "bearer"
```

---

## Use Cases

| Use Case | File | Description |
|---|---|---|
| RegisterUser | `register_user.py` | Create account, hash password, send verification email |
| LoginUser | `login_user.py` | Validate credentials, issue JWT pair |
| RefreshToken | `refresh_token.py` | Validate refresh token, issue new access token |
| LogoutUser | `logout_user.py` | Blacklist refresh token |
| ChangePassword | `change_password.py` | Validate old password, hash new |
| RequestPasswordReset | `request_password_reset.py` | Send reset email with OTP |
| ResetPassword | `reset_password.py` | Validate OTP, set new password |
| UpdateUserRole | `update_user_role.py` | Admin-only role change |
| ValidateToken | `validate_token.py` | Used by middleware in other services |

---

## API Endpoints

```
POST   /api/v1/auth/register          → RegisterUser
POST   /api/v1/auth/login             → LoginUser
POST   /api/v1/auth/refresh           → RefreshToken
POST   /api/v1/auth/logout            → LogoutUser
PUT    /api/v1/auth/password          → ChangePassword
POST   /api/v1/auth/password/reset    → RequestPasswordReset
POST   /api/v1/auth/password/confirm  → ResetPassword
GET    /api/v1/auth/me                → Current user profile
PUT    /api/v1/auth/me                → Update profile
PATCH  /api/v1/auth/users/{id}/role   → UpdateUserRole (admin only)
POST   /api/v1/auth/validate          → ValidateToken (internal service-to-service)
```

---

## Database Tables (schema: `auth`)

```sql
CREATE TABLE auth.users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(255) NOT NULL,
    role          VARCHAR(50)  NOT NULL,
    is_active     BOOLEAN DEFAULT true,
    is_verified   BOOLEAN DEFAULT false,
    created_at    TIMESTAMPTZ DEFAULT now(),
    updated_at    TIMESTAMPTZ DEFAULT now(),
    last_login    TIMESTAMPTZ
);

CREATE TABLE auth.refresh_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked    BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE auth.password_reset_otps (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    otp_hash   VARCHAR(255) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used       BOOLEAN DEFAULT false
);
```

---

## Alembic Migrations

```
migrations/versions/
├── 001_create_users_table.py
├── 002_create_refresh_tokens_table.py
└── 003_create_password_reset_otps_table.py
```

---

## Security Notes

- Passwords hashed with `bcrypt` (cost factor 12)
- JWT signed with RS256 — private key in auth-service only, public key shared to all services
- Refresh tokens stored as hashed values (SHA-256) in DB — never raw
- Failed login attempts tracked; account locked after 5 failures in 15 minutes
- Password reset OTPs expire in 10 minutes and are single-use

---

## External Dependencies

- `notification-service` → sends verification and password reset emails
