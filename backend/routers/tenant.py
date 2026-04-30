"""Tenant self-service router — authenticated tenant sees only their own data."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import get_supabase

router = APIRouter()


def _get_tenant(sb, user_id: str) -> dict:
    """Return the tenants row linked to this Supabase user, or raise 404."""
    res = (
        sb.table("tenants")
        .select("*, leasing_units(id, name, category, floor, status)")
        .eq("auth_user_id", user_id)
        .limit(1)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="Tenant record not found for this user")
    return res.data[0]


# ── Profile / me ─────────────────────────────────────────────────────

@router.get("/me")
async def get_me(user_id: str) -> dict[str, Any]:
    """Return tenant profile + linked unit. user_id passed by client from JWT."""
    sb = get_supabase()
    profile_res = sb.table("profiles").select("*").eq("id", user_id).limit(1).execute()
    profile = profile_res.data[0] if profile_res.data else {}
    tenant = _get_tenant(sb, user_id)
    return {**profile, "tenant": tenant}


# ── My Unit ──────────────────────────────────────────────────────────

@router.get("/my-unit")
async def get_my_unit(user_id: str) -> dict[str, Any]:
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)
    unit_id = tenant.get("leasing_unit_id")
    if not unit_id:
        raise HTTPException(status_code=404, detail="No unit linked to this tenant")

    unit_res = sb.table("leasing_units").select("*").eq("id", unit_id).limit(1).execute()
    if not unit_res.data:
        raise HTTPException(status_code=404, detail="Unit not found")

    unit = unit_res.data[0]
    areas_res = sb.table("area_entries").select("*").eq("leasing_unit_id", unit_id).execute()
    unit["area_entries"] = areas_res.data or []
    return unit


# ── My Lease ─────────────────────────────────────────────────────────

@router.get("/my-lease")
async def get_my_lease(user_id: str) -> dict[str, Any]:
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)
    res = (
        sb.table("leases")
        .select("*")
        .eq("tenant_id", tenant["id"])
        .order("start_date", desc=True)
        .limit(1)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="No lease found")
    return res.data[0]


# ── My Invoices ──────────────────────────────────────────────────────

@router.get("/my-invoices")
async def get_my_invoices(user_id: str) -> list[dict[str, Any]]:
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)
    res = (
        sb.table("transactions")
        .select("*")
        .eq("tenant_id", tenant["id"])
        .eq("type", "income")
        .order("date", desc=True)
        .execute()
    )
    return res.data or []


# ── My Maintenance Requests ───────────────────────────────────────────

@router.get("/my-maintenance")
async def get_my_maintenance(user_id: str) -> list[dict[str, Any]]:
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)
    res = (
        sb.table("maintenance_requests")
        .select("*")
        .eq("tenant_id", tenant["id"])
        .order("created_at", desc=True)
        .execute()
    )
    return res.data or []


class MaintenanceIn(BaseModel):
    title: str
    description: str | None = None
    category: str | None = None
    priority: str = "medium"


@router.post("/my-maintenance", status_code=201)
async def create_my_maintenance(user_id: str, payload: MaintenanceIn) -> dict[str, Any]:
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)
    row = {
        **payload.model_dump(),
        "tenant_id": tenant["id"],
        "leasing_unit_id": tenant.get("leasing_unit_id"),
        "status": "open",
    }
    res = sb.table("maintenance_requests").insert(row).execute()
    return res.data[0]


# ── My Queries ────────────────────────────────────────────────────────

@router.get("/my-queries")
async def get_my_queries(user_id: str) -> list[dict[str, Any]]:
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)
    res = (
        sb.table("tenant_queries")
        .select("*, tenant_query_replies(*)")
        .eq("tenant_id", tenant["id"])
        .order("created_at", desc=True)
        .execute()
    )
    return res.data or []


class QueryIn(BaseModel):
    subject: str
    body: str


@router.post("/my-queries", status_code=201)
async def create_my_query(user_id: str, payload: QueryIn) -> dict[str, Any]:
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)
    row = {
        **payload.model_dump(),
        "tenant_id": tenant["id"],
        "leasing_unit_id": tenant.get("leasing_unit_id"),
        "status": "open",
        "is_read_admin": False,
        "is_read_tenant": True,
    }
    res = sb.table("tenant_queries").insert(row).execute()
    return res.data[0]


@router.post("/my-queries/{query_id}/reply", status_code=201)
async def reply_to_query(query_id: str, user_id: str, body: str) -> dict[str, Any]:
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)
    # Verify ownership
    q = sb.table("tenant_queries").select("id").eq("id", query_id).eq("tenant_id", tenant["id"]).limit(1).execute()
    if not q.data:
        raise HTTPException(status_code=404, detail="Query not found")
    res = sb.table("tenant_query_replies").insert(
        {"query_id": query_id, "author_role": "tenant", "body": body}
    ).execute()
    return res.data[0]


# ── Admin: query replies ──────────────────────────────────────────────

@router.get("/queries")
async def admin_list_queries() -> list[dict[str, Any]]:
    """Admin endpoint — list all tenant queries."""
    sb = get_supabase()
    res = (
        sb.table("tenant_queries")
        .select("*, tenant_query_replies(*), tenants(first_name, last_name)")
        .order("created_at", desc=True)
        .execute()
    )
    return res.data or []


class AdminReplyIn(BaseModel):
    body: str


@router.post("/queries/{query_id}/reply", status_code=201)
async def admin_reply_query(query_id: str, payload: AdminReplyIn) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("tenant_query_replies").insert(
        {"query_id": query_id, "author_role": "admin", "body": payload.body}
    ).execute()
    sb.table("tenant_queries").update(
        {"status": "replied", "is_read_tenant": False}
    ).eq("id", query_id).execute()
    return res.data[0]
