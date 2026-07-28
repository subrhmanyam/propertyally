"""Shared authorization helpers for admin-facing routers.

The backend talks to Supabase with the service-role key (see db.py), which
bypasses RLS entirely — every table is fully readable/writable from here.
That means application code is the *only* authorization boundary: every
mutating admin endpoint must resolve which organization a resource belongs
to and confirm the caller is an admin member of that org before touching
anything. Endpoints that skip this check are reachable by any signed-in
user, including tenants, via direct API calls.

Extracted from routers/service_requests.py, which was the first router
this pattern was applied to.
"""

from __future__ import annotations

from fastapi import HTTPException


def unit_org_id(sb, unit_id: str | None) -> str | None:
    """Resolve a leasing_units.id to its owning organizations.id."""
    if not unit_id:
        return None
    res = sb.table("leasing_units").select("org_id").eq("id", unit_id).limit(1).execute()
    return res.data[0].get("org_id") if res.data else None


def require_org_admin(sb, user_id: str | None, org_id: str | None) -> None:
    """Raise 401/400/403 unless user_id is an admin member of org_id."""
    if not user_id:
        raise HTTPException(status_code=401, detail="user_id is required for this action.")
    if not org_id:
        raise HTTPException(
            status_code=400,
            detail="Could not resolve an organization for this resource.",
        )
    res = (
        sb.table("organization_members")
        .select("role")
        .eq("org_id", org_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
    )
    if not res.data or res.data[0].get("role") != "admin":
        raise HTTPException(
            status_code=403,
            detail="You do not have admin access to this organization.",
        )


def require_org_admin_for_unit(sb, user_id: str | None, unit_id: str | None) -> None:
    """Convenience wrapper for the common case: authorize against whichever
    org owns a given leasing unit."""
    require_org_admin(sb, user_id, unit_org_id(sb, unit_id))


def require_any_org_admin(sb, user_id: str | None) -> None:
    """For resources with no single owning property (e.g. an org-wide task
    or a global service-catalog entry) — require the caller to be an admin
    of at least one organization, rather than a specific one."""
    if not user_id:
        raise HTTPException(status_code=401, detail="user_id is required for this action.")
    res = (
        sb.table("organization_members")
        .select("org_id")
        .eq("user_id", user_id)
        .eq("role", "admin")
        .limit(1)
        .execute()
    )
    if not res.data:
        raise HTTPException(
            status_code=403,
            detail="You do not have admin access to this organization.",
        )
