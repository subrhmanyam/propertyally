"""Auth helper router — registration and profile lookup."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import get_supabase

router = APIRouter()


class RegisterIn(BaseModel):
    email: str
    password: str
    first_name: str
    last_name: str
    role: str = "tenant"  # tenant | admin


@router.post("/register", status_code=201)
async def register(payload: RegisterIn) -> dict[str, Any]:
    """Create a new Supabase auth user, set their profile role, and (for tenants) create a tenants row."""
    if payload.role not in ("tenant", "admin"):
        raise HTTPException(status_code=400, detail="role must be 'tenant' or 'admin'")

    sb = get_supabase()

    # Create auth user — email_confirm=True skips the confirmation email in dev
    try:
        user_res = sb.auth.admin.create_user(
            {
                "email": payload.email,
                "password": payload.password,
                "email_confirm": True,
            }
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=str(exc))

    user = user_res.user
    if not user:
        raise HTTPException(status_code=500, detail="User creation failed")

    user_id = str(user.id)

    # The handle_new_user trigger creates the profile with role='admin' by default.
    # Update the role to what was requested.
    sb.table("profiles").update(
        {"full_name": f"{payload.first_name} {payload.last_name}", "role": payload.role}
    ).eq("id", user_id).execute()

    # For tenants, create the tenants row linked to this auth user
    if payload.role == "tenant":
        existing = (
            sb.table("tenants")
            .select("id")
            .eq("auth_user_id", user_id)
            .limit(1)
            .execute()
        )
        if not existing.data:
            sb.table("tenants").insert(
                {
                    "auth_user_id": user_id,
                    "first_name": payload.first_name,
                    "last_name": payload.last_name,
                    "email": payload.email,
                }
            ).execute()

    return {"id": user_id, "email": payload.email, "role": payload.role}


@router.get("/profile")
async def get_profile(user_id: str) -> dict[str, Any]:
    """Return this user's role (used to decide which app shell to route into).

    `profiles` is not a reliable source of truth for tenants — accounts
    created directly against a tenants row (rather than through /register)
    have no profiles row at all, which used to 404 here and made the
    frontend's catch-all fall back to 'admin', silently dropping tenants
    into the admin shell. The tenants table (via auth_user_id) is checked
    first since it's the actual ground truth for "is this user a tenant."
    """
    sb = get_supabase()

    tenant_res = (
        sb.table("tenants")
        .select("id, first_name, last_name, email")
        .eq("auth_user_id", user_id)
        .limit(1)
        .execute()
    )
    if tenant_res.data:
        row = tenant_res.data[0]
        return {
            "id": user_id,
            "role": "tenant",
            "full_name": f"{row.get('first_name', '')} {row.get('last_name', '')}".strip(),
            "email": row.get("email"),
        }

    res = (
        sb.table("profiles")
        .select("id, role, full_name, email")
        .eq("id", user_id)
        .limit(1)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="Profile not found")
    return res.data[0]
