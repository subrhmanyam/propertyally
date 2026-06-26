"""Leasing units router — CRUD for leasing_units, area_entries, and unit agreements."""

from __future__ import annotations

import base64
import json
from typing import Any

import anthropic
from fastapi import APIRouter, HTTPException, UploadFile, File
from pydantic import BaseModel

from db import get_supabase

_anthropic_client: anthropic.Anthropic | None = None


def _get_anthropic() -> anthropic.Anthropic:
    global _anthropic_client
    if _anthropic_client is None:
        _anthropic_client = anthropic.Anthropic()
    return _anthropic_client

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


# ---------------------------------------------------------------------------
# Agreement document — upload, extract, and retrieve
# ---------------------------------------------------------------------------

_ALLOWED_MIME = {
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/webp",
}

_MIME_FROM_EXT = {
    "pdf": "application/pdf",
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
}


@router.post("/{unit_id}/agreement", status_code=201)
async def upload_agreement(
    unit_id: str,
    file: UploadFile = File(...),
) -> dict[str, Any]:
    """
    Upload a lease agreement (PDF or image) for a unit.
    Claude extracts key fields automatically and stores them in unit_agreements.
    Subsequent uploads replace the previous record for the same unit.
    """
    from agents.document_extractor import extract_agreement_fields

    ext = (file.filename or "").rsplit(".", 1)[-1].lower()
    media_type = file.content_type or _MIME_FROM_EXT.get(ext, "")

    if media_type not in _ALLOWED_MIME:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported file type '{media_type}'. Upload a PDF or image.",
        )

    file_bytes = await file.read()
    if len(file_bytes) > 20 * 1024 * 1024:  # 20 MB guard
        raise HTTPException(status_code=413, detail="File too large (max 20 MB).")

    try:
        fields = extract_agreement_fields(file_bytes, media_type, file.filename or "")
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Extraction failed: {exc}")

    sb = get_supabase()
    row = {
        "unit_id": unit_id,
        "document_name": file.filename,
        "document_type": "pdf" if media_type == "application/pdf" else "image",
        **{k: v for k, v in fields.items()},
        "raw_extraction": fields,
    }

    # Upsert — one agreement record per unit
    existing = sb.table("unit_agreements").select("id").eq("unit_id", unit_id).execute()
    if existing.data:
        res = (
            sb.table("unit_agreements")
            .update(row)
            .eq("unit_id", unit_id)
            .execute()
        )
    else:
        res = sb.table("unit_agreements").insert(row).execute()

    return res.data[0]


@router.get("/{unit_id}/agreement")
async def get_agreement(unit_id: str) -> dict[str, Any]:
    """Returns the extracted agreement fields for a unit. 404 if none uploaded yet."""
    sb = get_supabase()
    res = (
        sb.table("unit_agreements")
        .select("*")
        .eq("unit_id", unit_id)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="No agreement uploaded for this unit.")
    return res.data[0]


@router.post("/import-pdf")
async def import_pdf_units(
    file: UploadFile = File(...),
) -> list[dict[str, Any]]:
    """
    Parse a Leasing Area Statement PDF (or image) and return a list of leasing units.
    Uses Claude to extract property name, floor, category, area entries, and status.
    """
    ext = (file.filename or "").rsplit(".", 1)[-1].lower()
    media_type = file.content_type or _MIME_FROM_EXT.get(ext, "application/pdf")
    if media_type not in _ALLOWED_MIME:
        raise HTTPException(status_code=415, detail="Upload a PDF or image.")

    file_bytes = await file.read()
    if len(file_bytes) > 20 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (max 20 MB).")

    b64 = base64.standard_b64encode(file_bytes).decode()

    prompt = """
You are parsing a Leasing Area Statement spreadsheet exported to PDF.
Extract every property (unit) listed and return a JSON array.

Each object must have:
  name        - property name (string)
  company_name - portfolio/owner name from the filename or header if visible, else ""
  category    - one of: Restaurant, Brewery, Cafe & Restaurant, Office, Residence, Shop,
                 Event/Party, Studio Room, Co-working, Parking, Land/Site, Other
  floor       - Ground Floor | First Floor | Second Floor | Outdoor | or combined like
                 "Ground Floor & First Floor" when the property spans multiple floors
  status      - occupied | vacant | in_house | owner_occupied
  areas       - array of {type: "covered"|"open"|"common", sqft: number, rate: number}

Rules:
- If a property spans multiple floor sections, merge all area rows under one unit.
- "In-house operation" → in_house, "Owner-occupied" → owner_occupied.
- Common Area / Pathway rows: type = "common", rate = 0 if not stated.
- Rows with #REF! for rate: use 0.
- Return ONLY valid JSON, no markdown, no explanation.
"""

    msg = _get_anthropic().messages.create(
        model="claude-opus-4-8",
        max_tokens=4096,
        messages=[{
            "role": "user",
            "content": [
                {
                    "type": "document",
                    "source": {"type": "base64", "media_type": media_type, "data": b64},
                },
                {"type": "text", "text": prompt},
            ],
        }],
    )

    raw = msg.content[0].text.strip()
    # Strip markdown fences if present
    if raw.startswith("```"):
        raw = raw.split("\n", 1)[1].rsplit("```", 1)[0].strip()

    try:
        units = json.loads(raw)
    except json.JSONDecodeError as e:
        raise HTTPException(status_code=502, detail=f"Claude returned invalid JSON: {e}")

    if not isinstance(units, list):
        raise HTTPException(status_code=502, detail="Expected a JSON array from Claude.")

    return units


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
