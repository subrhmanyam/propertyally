"""Applications router — prospective tenant applications."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from db import get_supabase

router = APIRouter()


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
async def create_application(payload: ApplicationIn) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("applications").insert(payload.model_dump()).execute()
    return res.data[0]


@router.put("/{app_id}")
async def update_application(app_id: str, payload: ApplicationIn) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("applications").update(payload.model_dump()).eq("id", app_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Application not found")
    return res.data[0]


@router.delete("/{app_id}", status_code=204)
async def delete_application(app_id: str) -> None:
    sb = get_supabase()
    sb.table("applications").delete().eq("id", app_id).execute()
