"""Service catalog router — browse and manage the catalog of property services."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from auth_utils import require_any_org_admin
from db import get_supabase

router = APIRouter()


# ── Public: browse catalog (filtered by unit category) ───────────────

@router.get("/")
async def list_catalog(category: str | None = None) -> list[dict[str, Any]]:
    """Return active service catalog items, optionally filtered by property category."""
    sb = get_supabase()
    query = sb.table("service_catalog").select("*").eq("is_active", True).order("category").order("name")
    res = query.execute()
    items = res.data or []
    if category:
        items = [i for i in items if category in (i.get("property_types") or [])]
    return items


@router.get("/{service_id}")
async def get_catalog_item(service_id: str) -> dict[str, Any]:
    res = get_supabase().table("service_catalog").select("*").eq("id", service_id).limit(1).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Service not found")
    return res.data[0]


# ── Admin: manage catalog ─────────────────────────────────────────────

class ServiceIn(BaseModel):
    name: str
    category: str
    description: str | None = None
    property_types: list[str] = []
    typical_sla_hours: int = 24
    is_active: bool = True


@router.post("/", status_code=201)
async def create_catalog_item(user_id: str, payload: ServiceIn) -> dict[str, Any]:
    sb = get_supabase()
    require_any_org_admin(sb, user_id)
    res = sb.table("service_catalog").insert(payload.model_dump()).execute()
    return res.data[0]


@router.put("/{service_id}")
async def update_catalog_item(service_id: str, user_id: str, payload: ServiceIn) -> dict[str, Any]:
    sb = get_supabase()
    require_any_org_admin(sb, user_id)
    res = (
        sb.table("service_catalog")
        .update(payload.model_dump())
        .eq("id", service_id)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="Service not found")
    return res.data[0]


@router.delete("/{service_id}", status_code=204)
async def delete_catalog_item(service_id: str, user_id: str) -> None:
    sb = get_supabase()
    require_any_org_admin(sb, user_id)
    sb.table("service_catalog").update({"is_active": False}).eq("id", service_id).execute()
