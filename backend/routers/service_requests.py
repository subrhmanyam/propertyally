"""Service requests router — tenant submits service requests; admin manages them."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import get_supabase

router = APIRouter()


def _get_tenant(sb, user_id: str) -> dict:
    res = (
        sb.table("tenants")
        .select("id, leasing_unit_id")
        .eq("auth_user_id", user_id)
        .limit(1)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="Tenant record not found for this user")
    return res.data[0]


# ── Tenant: submit and view own requests ──────────────────────────────

class ServiceRequestIn(BaseModel):
    service_id: str | None = None
    service_name: str | None = None
    description: str | None = None
    priority: str = "normal"
    photos: list[str] = []


@router.post("/", status_code=201)
async def create_service_request(user_id: str, payload: ServiceRequestIn) -> dict[str, Any]:
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)

    # Resolve service_name from catalog if only service_id given
    service_name = payload.service_name
    if not service_name and payload.service_id:
        cat = sb.table("service_catalog").select("name").eq("id", payload.service_id).limit(1).execute()
        service_name = cat.data[0]["name"] if cat.data else None

    row = {
        **payload.model_dump(),
        "service_name": service_name,
        "tenant_id": tenant["id"],
        "leasing_unit_id": tenant.get("leasing_unit_id"),
        "status": "open",
    }
    res = sb.table("service_requests").insert(row).execute()
    return res.data[0]


@router.get("/my")
async def get_my_service_requests(user_id: str) -> list[dict[str, Any]]:
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)
    res = (
        sb.table("service_requests")
        .select("*, service_catalog(name, category)")
        .eq("tenant_id", tenant["id"])
        .order("created_at", desc=True)
        .execute()
    )
    return res.data or []


# ── Admin: create on behalf of any unit ──────────────────────────

class AdminServiceRequestIn(BaseModel):
    leasing_unit_id: str
    service_id: str | None = None
    service_name: str | None = None
    description: str | None = None
    priority: str = "normal"
    tenant_id: str | None = None


@router.post("/admin", status_code=201)
async def admin_create_service_request(payload: AdminServiceRequestIn) -> dict[str, Any]:
    sb = get_supabase()

    service_name = payload.service_name
    if not service_name and payload.service_id:
        cat = sb.table("service_catalog").select("name").eq("id", payload.service_id).limit(1).execute()
        service_name = cat.data[0]["name"] if cat.data else None

    # Auto-link tenant if not provided
    tenant_id = payload.tenant_id
    if not tenant_id:
        t = sb.table("tenants").select("id").eq("leasing_unit_id", payload.leasing_unit_id).limit(1).execute()
        tenant_id = t.data[0]["id"] if t.data else None

    row = {
        "leasing_unit_id": payload.leasing_unit_id,
        "service_id": payload.service_id,
        "service_name": service_name,
        "description": payload.description,
        "priority": payload.priority,
        "tenant_id": tenant_id,
        "status": "open",
    }
    res = sb.table("service_requests").insert(row).execute()
    return res.data[0]


# ── Admin: all requests ───────────────────────────────────────────────

@router.get("/")
async def list_service_requests(
    status: str | None = None,
    unit_id: str | None = None,
) -> list[dict[str, Any]]:
    sb = get_supabase()
    query = (
        sb.table("service_requests")
        .select("*, service_catalog(name, category), tenants(first_name, last_name)")
        .order("created_at", desc=True)
    )
    if status:
        query = query.eq("status", status)
    if unit_id:
        query = query.eq("leasing_unit_id", unit_id)
    return query.execute().data or []


@router.get("/{request_id}")
async def get_service_request(request_id: str) -> dict[str, Any]:
    res = (
        get_supabase()
        .table("service_requests")
        .select("*, service_catalog(name, category), tenants(first_name, last_name)")
        .eq("id", request_id)
        .limit(1)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="Request not found")
    return res.data[0]


class ServiceRequestUpdate(BaseModel):
    status: str | None = None
    assigned_to: str | None = None
    scheduled_at: str | None = None
    admin_notes: str | None = None
    tenant_rating: int | None = None


@router.patch("/{request_id}")
async def update_service_request(request_id: str, payload: ServiceRequestUpdate) -> dict[str, Any]:
    updates = {k: v for k, v in payload.model_dump().items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    if payload.status == "completed":
        updates["completed_at"] = "now()"
    res = (
        get_supabase()
        .table("service_requests")
        .update(updates)
        .eq("id", request_id)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="Request not found")
    return res.data[0]
