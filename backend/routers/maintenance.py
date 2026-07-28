"""Maintenance router — requests, comments, and photo uploads."""

from __future__ import annotations

import os
import uuid
from typing import Any

from fastapi import APIRouter, File, HTTPException, Query, UploadFile
from pydantic import BaseModel

from auth_utils import require_any_org_admin, require_org_admin_for_unit
from db import get_supabase

router = APIRouter()


def _require_admin(sb, user_id: str, unit_id: str | None) -> None:
    if unit_id:
        require_org_admin_for_unit(sb, user_id, unit_id)
    else:
        require_any_org_admin(sb, user_id)


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
async def create_request(user_id: str, payload: MaintenanceRequestIn) -> dict[str, Any]:
    sb = get_supabase()
    _require_admin(sb, user_id, payload.leasing_unit_id)
    res = sb.table("maintenance_requests").insert(payload.model_dump()).execute()
    return res.data[0]


@router.put("/{request_id}")
async def update_request(request_id: str, user_id: str, payload: MaintenanceRequestIn) -> dict[str, Any]:
    sb = get_supabase()
    current = sb.table("maintenance_requests").select("leasing_unit_id").eq("id", request_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Maintenance request not found")
    _require_admin(sb, user_id, payload.leasing_unit_id or current.data[0].get("leasing_unit_id"))
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
async def delete_request(request_id: str, user_id: str) -> None:
    sb = get_supabase()
    current = sb.table("maintenance_requests").select("leasing_unit_id").eq("id", request_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Maintenance request not found")
    _require_admin(sb, user_id, current.data[0].get("leasing_unit_id"))
    sb.table("maintenance_requests").delete().eq("id", request_id).execute()


@router.post("/{request_id}/comments", status_code=201)
async def add_comment(request_id: str, user_id: str, payload: CommentIn) -> dict[str, Any]:
    sb = get_supabase()
    current = sb.table("maintenance_requests").select("leasing_unit_id").eq("id", request_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Maintenance request not found")
    _require_admin(sb, user_id, current.data[0].get("leasing_unit_id"))
    res = sb.table("maintenance_comments").insert(
        {"request_id": request_id, **payload.model_dump()}
    ).execute()
    return res.data[0]


_ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
_MAX_PHOTO_BYTES = 10 * 1024 * 1024  # 10 MB


@router.post("/{request_id}/photos")
async def upload_photo(
    request_id: str,
    user_id: str,
    file: UploadFile = File(...),
) -> dict[str, Any]:
    """Upload a photo for a maintenance request. Stores in Supabase Storage."""
    if file.content_type not in _ALLOWED_IMAGE_TYPES:
        raise HTTPException(status_code=400, detail="Only JPEG, PNG, WebP, or GIF images are accepted.")

    data = await file.read()
    if len(data) > _MAX_PHOTO_BYTES:
        raise HTTPException(status_code=413, detail="Image must be under 10 MB.")

    sb = get_supabase()

    # Verify request exists
    existing = sb.table("maintenance_requests").select("id,photos,leasing_unit_id").eq("id", request_id).single().execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Maintenance request not found")
    _require_admin(sb, user_id, existing.data.get("leasing_unit_id"))

    bucket = os.getenv("MAINTENANCE_PHOTOS_BUCKET", "maintenance-photos")
    ext = (file.filename or "photo.jpg").rsplit(".", 1)[-1].lower()
    storage_path = f"{request_id}/{uuid.uuid4()}.{ext}"

    try:
        sb.storage.from_(bucket).upload(
            path=storage_path,
            file=data,
            file_options={"content-type": file.content_type},
        )
        supabase_url = os.getenv("SUPABASE_URL", "").rstrip("/")
        photo_url = f"{supabase_url}/storage/v1/object/public/{bucket}/{storage_path}"
    except Exception:
        # Fallback: store as data URI if storage bucket is not configured
        import base64 as _b64
        mime = file.content_type or "image/jpeg"
        photo_url = f"data:{mime};base64,{_b64.b64encode(data).decode()}"

    current_photos: list[str] = existing.data.get("photos") or []
    updated_photos = current_photos + [photo_url]

    res = (
        sb.table("maintenance_requests")
        .update({"photos": updated_photos})
        .eq("id", request_id)
        .execute()
    )
    return res.data[0]


@router.delete("/{request_id}/photos")
async def delete_photo(request_id: str, user_id: str, photo_url: str) -> dict[str, Any]:
    """Remove a photo URL from a maintenance request's photos array."""
    sb = get_supabase()
    existing = sb.table("maintenance_requests").select("id,photos,leasing_unit_id").eq("id", request_id).single().execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Maintenance request not found")
    _require_admin(sb, user_id, existing.data.get("leasing_unit_id"))

    photos = [p for p in (existing.data.get("photos") or []) if p != photo_url]
    res = sb.table("maintenance_requests").update({"photos": photos}).eq("id", request_id).execute()
    return res.data[0]
