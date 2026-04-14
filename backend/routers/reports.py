"""Reports router — saved and generated reports."""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import get_supabase

router = APIRouter()


class ReportIn(BaseModel):
    name: str
    type: str  # financial | occupancy | maintenance | custom
    filters: dict[str, Any] = {}
    generated_by: str | None = None


@router.get("/")
async def list_reports() -> list[dict[str, Any]]:
    sb = get_supabase()
    return sb.table("reports").select("*").order("created_at", desc=True).execute().data or []


@router.get("/{report_id}")
async def get_report(report_id: str) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("reports").select("*").eq("id", report_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Report not found")
    return res.data


@router.post("/", status_code=201)
async def create_report(payload: ReportIn) -> dict[str, Any]:
    sb = get_supabase()
    data = payload.model_dump()
    data["generated_at"] = datetime.now(tz=timezone.utc).isoformat()
    res = sb.table("reports").insert(data).execute()
    return res.data[0]


@router.delete("/{report_id}", status_code=204)
async def delete_report(report_id: str) -> None:
    sb = get_supabase()
    sb.table("reports").delete().eq("id", report_id).execute()
