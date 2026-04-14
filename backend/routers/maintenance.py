"""Maintenance router — requests and comments."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from db import get_supabase

router = APIRouter()


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class MaintenanceRequestIn(BaseModel):
    title: str
    description: str | None = None
    priority: str = "medium"  # low | medium | high | urgent
    status: str = "open"
    category: str | None = None
    leasing_unit_id: str | None = None
    tenant_id: str | None = None
    assigned_to: str | None = None
    assigned_email: str | None = None
    estimated_cost: float | None = None
    actual_cost: float | None = None
    scheduled_date: str | None = None
    completed_date: str | None = None
    notes: str | None = None


class CommentIn(BaseModel):
    author_id: str | None = None
    body: str


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("/")
async def list_requests(
    status: str | None = Query(None),
    priority: str | None = Query(None),
    leasing_unit_id: str | None = Query(None),
) -> list[dict[str, Any]]:
    sb = get_supabase()
    q = sb.table("maintenance_requests").select("*")
    if status:
        q = q.eq("status", status)
    if priority:
        q = q.eq("priority", priority)
    if leasing_unit_id:
        q = q.eq("leasing_unit_id", leasing_unit_id)
    return q.order("created_at", desc=True).execute().data or []


@router.get("/{request_id}")
async def get_request(request_id: str) -> dict[str, Any]:
    sb = get_supabase()
    res = (
        sb.table("maintenance_requests")
        .select("*, maintenance_comments(*)")
        .eq("id", request_id)
        .single()
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="Maintenance request not found")
    return res.data


@router.post("/", status_code=201)
async def create_request(payload: MaintenanceRequestIn) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("maintenance_requests").insert(payload.model_dump()).execute()
    return res.data[0]


@router.put("/{request_id}")
async def update_request(request_id: str, payload: MaintenanceRequestIn) -> dict[str, Any]:
    sb = get_supabase()
    res = (
        sb.table("maintenance_requests")
        .update(payload.model_dump())
        .eq("id", request_id)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="Maintenance request not found")
    return res.data[0]


@router.delete("/{request_id}", status_code=204)
async def delete_request(request_id: str) -> None:
    sb = get_supabase()
    sb.table("maintenance_requests").delete().eq("id", request_id).execute()


@router.post("/{request_id}/comments", status_code=201)
async def add_comment(request_id: str, payload: CommentIn) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("maintenance_comments").insert(
        {"request_id": request_id, **payload.model_dump()}
    ).execute()
    return res.data[0]
