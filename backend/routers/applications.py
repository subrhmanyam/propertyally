"""Applications router — prospective tenant applications."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from auth_utils import require_any_org_admin, require_org_admin_for_unit
from db import get_supabase

router = APIRouter()


def _require_admin(sb, user_id: str, unit_id: str | None) -> None:
    if unit_id:
        require_org_admin_for_unit(sb, user_id, unit_id)
    else:
        require_any_org_admin(sb, user_id)


class ApplicationIn(BaseModel):
    applicant_name: str
    email: str | None = None
    phone: str | None = None
    leasing_unit_id: str | None = None
    status: str = "pending"
    monthly_income: float | None = None
    desired_move_in: str | None = None
    message: str | None = None
    reviewed_by: str | None = None
    reviewed_at: str | None = None


@router.get("/")
async def list_applications(status: str | None = Query(None)) -> list[dict[str, Any]]:
    sb = get_supabase()
    q = sb.table("applications").select("*")
    if status:
        q = q.eq("status", status)
    return q.order("created_at", desc=True).execute().data or []


@router.get("/{app_id}")
async def get_application(app_id: str) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("applications").select("*").eq("id", app_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Application not found")
    return res.data


@router.post("/", status_code=201)
async def create_application(user_id: str, payload: ApplicationIn) -> dict[str, Any]:
    sb = get_supabase()
    _require_admin(sb, user_id, payload.leasing_unit_id)
    res = sb.table("applications").insert(payload.model_dump()).execute()
    return res.data[0]


@router.put("/{app_id}")
async def update_application(app_id: str, user_id: str, payload: ApplicationIn) -> dict[str, Any]:
    sb = get_supabase()
    current = sb.table("applications").select("leasing_unit_id").eq("id", app_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Application not found")
    _require_admin(sb, user_id, payload.leasing_unit_id or current.data[0].get("leasing_unit_id"))
    res = sb.table("applications").update(payload.model_dump()).eq("id", app_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Application not found")
    return res.data[0]


@router.delete("/{app_id}", status_code=204)
async def delete_application(app_id: str, user_id: str) -> None:
    sb = get_supabase()
    current = sb.table("applications").select("leasing_unit_id").eq("id", app_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Application not found")
    _require_admin(sb, user_id, current.data[0].get("leasing_unit_id"))
    sb.table("applications").delete().eq("id", app_id).execute()
