"""Tenants router — CRUD for tenants and leases."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from auth_utils import require_any_org_admin, require_org_admin_for_unit
from db import get_supabase

router = APIRouter()


def _require_admin(sb, user_id: str, unit_id: str | None) -> None:
    if unit_id:
        require_org_admin_for_unit(sb, user_id, unit_id)
    else:
        require_any_org_admin(sb, user_id)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class TenantIn(BaseModel):
    first_name: str
    last_name: str
    email: str | None = None
    phone: str | None = None
    status: str = "active"
    leasing_unit_id: str | None = None
    move_in_date: str | None = None
    emergency_contact_name: str | None = None
    emergency_contact_phone: str | None = None
    notes: str | None = None
    company_name: str | None = None
    business_type: str | None = None
    floor: str | None = None
    area_entries: list | None = None


class LeaseIn(BaseModel):
    tenant_id: str
    leasing_unit_id: str | None = None
    start_date: str
    end_date: str
    monthly_rent: float
    deposit_amount: float = 0
    status: str = "active"
    signed_date: str | None = None
    document_url: str | None = None


# ---------------------------------------------------------------------------
# Tenants
# ---------------------------------------------------------------------------


@router.get("/")
async def list_tenants(status: str | None = None) -> list[dict[str, Any]]:
    sb = get_supabase()
    q = sb.table("tenants").select("*")
    if status:
        q = q.eq("status", status)
    return q.order("created_at", desc=True).execute().data or []


@router.get("/{tenant_id}")
async def get_tenant(tenant_id: str) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("tenants").select("*, leases(*)").eq("id", tenant_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Tenant not found")
    return res.data


@router.post("/", status_code=201)
async def create_tenant(user_id: str, payload: TenantIn) -> dict[str, Any]:
    sb = get_supabase()
    _require_admin(sb, user_id, payload.leasing_unit_id)
    res = sb.table("tenants").insert(payload.model_dump(exclude_none=True)).execute()
    return res.data[0]


@router.put("/{tenant_id}")
async def update_tenant(tenant_id: str, user_id: str, payload: TenantIn) -> dict[str, Any]:
    sb = get_supabase()
    current = sb.table("tenants").select("leasing_unit_id").eq("id", tenant_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Tenant not found")
    _require_admin(sb, user_id, payload.leasing_unit_id or current.data[0].get("leasing_unit_id"))
    res = sb.table("tenants").update(payload.model_dump(exclude_none=True)).eq("id", tenant_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Tenant not found")
    return res.data[0]


@router.delete("/{tenant_id}", status_code=204)
async def delete_tenant(tenant_id: str, user_id: str) -> None:
    sb = get_supabase()
    current = sb.table("tenants").select("leasing_unit_id").eq("id", tenant_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Tenant not found")
    _require_admin(sb, user_id, current.data[0].get("leasing_unit_id"))
    sb.table("tenants").delete().eq("id", tenant_id).execute()


# ---------------------------------------------------------------------------
# Leases
# ---------------------------------------------------------------------------


@router.get("/{tenant_id}/leases")
async def list_leases(tenant_id: str) -> list[dict[str, Any]]:
    sb = get_supabase()
    return sb.table("leases").select("*").eq("tenant_id", tenant_id).execute().data or []


@router.post("/{tenant_id}/leases", status_code=201)
async def create_lease(tenant_id: str, user_id: str, payload: LeaseIn) -> dict[str, Any]:
    sb = get_supabase()
    _require_admin(sb, user_id, payload.leasing_unit_id)
    data = payload.model_dump()
    data["tenant_id"] = tenant_id
    res = sb.table("leases").insert(data).execute()
    return res.data[0]
