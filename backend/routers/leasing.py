"""Leasing units router — CRUD for leasing_units and area_entries."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import get_supabase

router = APIRouter()


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class AreaEntryIn(BaseModel):
    type: str  # covered | open | common
    sqft: float
    rate: float


class LeasingUnitIn(BaseModel):
    id: str | None = None
    name: str
    category: str
    floor: str
    status: str = "vacant"
    contact: str | None = None
    email: str | None = None
    notes: str | None = None
    areas: list[AreaEntryIn] = []


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("/")
async def list_units() -> list[dict[str, Any]]:
    sb = get_supabase()
    res = sb.table("leasing_units").select("*, area_entries(*)").execute()
    return res.data or []


@router.get("/{unit_id}")
async def get_unit(unit_id: str) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("leasing_units").select("*, area_entries(*)").eq("id", unit_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Unit not found")
    return res.data


@router.post("/", status_code=201)
async def create_unit(payload: LeasingUnitIn) -> dict[str, Any]:
    sb = get_supabase()
    unit_data = payload.model_dump(exclude={"areas"})
    if not unit_data.get("id"):
        import uuid
        unit_data["id"] = str(uuid.uuid4())

    unit_res = sb.table("leasing_units").insert(unit_data).execute()
    unit = unit_res.data[0]

    if payload.areas:
        area_rows = [
            {"leasing_unit_id": unit["id"], **a.model_dump()}
            for a in payload.areas
        ]
        sb.table("area_entries").insert(area_rows).execute()

    return await get_unit(unit["id"])


@router.put("/{unit_id}")
async def update_unit(unit_id: str, payload: LeasingUnitIn) -> dict[str, Any]:
    sb = get_supabase()
    unit_data = payload.model_dump(exclude={"areas", "id"})
    sb.table("leasing_units").update(unit_data).eq("id", unit_id).execute()

    # Replace area entries
    sb.table("area_entries").delete().eq("leasing_unit_id", unit_id).execute()
    if payload.areas:
        area_rows = [
            {"leasing_unit_id": unit_id, **a.model_dump()}
            for a in payload.areas
        ]
        sb.table("area_entries").insert(area_rows).execute()

    return await get_unit(unit_id)


@router.delete("/{unit_id}", status_code=204)
async def delete_unit(unit_id: str) -> None:
    sb = get_supabase()
    sb.table("leasing_units").delete().eq("id", unit_id).execute()


@router.get("/summary/occupancy")
async def occupancy_summary() -> dict[str, Any]:
    units = (await list_units())
    total = len(units)
    occupied = sum(1 for u in units if u.get("status") == "occupied")
    vacant = sum(1 for u in units if u.get("status") == "vacant")
    return {
        "total": total,
        "occupied": occupied,
        "vacant": vacant,
        "in_house": sum(1 for u in units if u.get("status") == "in_house"),
        "owner_occupied": sum(1 for u in units if u.get("status") == "owner_occupied"),
        "occupancy_rate": round(occupied / total * 100, 1) if total else 0,
    }
