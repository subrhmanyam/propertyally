"""Generic document upload — stores arbitrary files in Google Cloud Storage
under org_{org_id}/properties/{property_id}/{category}/... and records them
in the `documents` table. See gcs.py for the folder-structure rationale."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

import gcs
from db import get_supabase

router = APIRouter()

_MAX_BYTES = 20 * 1024 * 1024


def _resolve_org_id(sb, org_id: str | None, leasing_unit_id: str | None) -> str:
    """A document always belongs to an org — either passed explicitly or
    inherited from the property (leasing unit) it's attached to."""
    if org_id:
        return org_id
    if leasing_unit_id:
        res = (
            sb.table("leasing_units")
            .select("org_id")
            .eq("id", leasing_unit_id)
            .single()
            .execute()
        )
        unit_org_id = res.data.get("org_id") if res.data else None
        if unit_org_id:
            return unit_org_id
    raise HTTPException(
        status_code=400,
        detail="org_id is required (either directly, or via a leasing_unit_id that has one set).",
    )


@router.post("/upload", status_code=201)
async def upload_document(
    file: UploadFile = File(...),
    doc_type: str = Form("other"),
    leasing_unit_id: str | None = Form(None),
    org_id: str | None = Form(None),
) -> dict[str, Any]:
    data = await file.read()
    if len(data) > _MAX_BYTES:
        raise HTTPException(status_code=413, detail="File too large (max 20 MB).")

    sb = get_supabase()
    resolved_org_id = _resolve_org_id(sb, org_id, leasing_unit_id)

    filename = file.filename or "upload"
    storage_path, file_url = gcs.upload_bytes(
        org_id=resolved_org_id,
        category=doc_type,
        filename=filename,
        data=data,
        content_type=file.content_type or "application/octet-stream",
        property_id=leasing_unit_id,
    )

    row = {
        "name": filename,
        "type": doc_type,
        "file_url": file_url,
        "storage_path": storage_path,
        "file_size": len(data),
        "leasing_unit_id": leasing_unit_id,
        "org_id": resolved_org_id,
    }
    res = sb.table("documents").insert(row).execute()
    return res.data[0]
