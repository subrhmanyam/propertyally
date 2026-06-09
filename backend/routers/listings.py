"""Listings router — public-facing property adverts and lead analytics."""

from __future__ import annotations

from os import getenv
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from db import get_supabase

router = APIRouter()


SUPABASE_LISTING_MEDIA_BUCKET = getenv('SUPABASE_LISTING_MEDIA_BUCKET')


def _resolve_media_url(value: str) -> str:
    if not value:
        return value
    if value.startswith('http://') or value.startswith('https://'):
        return value
    if SUPABASE_LISTING_MEDIA_BUCKET:
        clean_value = value.lstrip('/')
        supabase_url = getenv('SUPABASE_URL', '').rstrip('/')
        if supabase_url:
            return f"{supabase_url}/storage/v1/object/public/{SUPABASE_LISTING_MEDIA_BUCKET}/{clean_value}"
    return value


def _normalize_listing_media(item: dict[str, Any]) -> dict[str, Any]:
    normalized = dict(item)
    normalized['photos'] = [
        _resolve_media_url(photo) for photo in normalized.get('photos', []) or []
    ]
    normalized['video_urls'] = [
        _resolve_media_url(url) for url in normalized.get('video_urls', []) or []
    ]
    normalized['virtual_tour_url'] = _resolve_media_url(normalized.get('virtual_tour_url', '') or '')
    return normalized


class ListingIn(BaseModel):
    leasing_unit_id: str | None = None
    title: str
    description: str | None = None
    monthly_rent: float
    available_from: str | None = None
    is_published: bool = False
    contact_email: str | None = None
    contact_phone: str | None = None
    photos: list[str] = []
    video_urls: list[str] = []
    virtual_tour_url: str | None = None
    features: list[str] = []
    views_count: int | None = None
    inquiry_count: int | None = None


class InquiryIn(BaseModel):
    inquirer_name: str
    inquirer_email: str
    inquirer_phone: str | None = None
    message: str
    preferred_move_in: str | None = None


@router.get("/")
async def list_listings(
    published_only: bool = Query(False),
    status: str | None = None,
    min_rent: float | None = None,
    max_rent: float | None = None,
    property_type: str | None = None,
    available_from: str | None = None,
    city: str | None = None,
    bedrooms: int | None = None,
) -> list[dict[str, Any]]:
    sb = get_supabase()
    q = sb.table("listings").select("*")
    if published_only:
        q = q.eq("is_published", True)
    if status:
        q = q.eq("status", status)
    if min_rent is not None:
        q = q.gte("monthly_rent", min_rent)
    if max_rent is not None:
        q = q.lte("monthly_rent", max_rent)
    if property_type:
        q = q.eq("property_type", property_type)
    if available_from:
        q = q.gte("available_from", available_from)
    if city:
        q = q.ilike("city", f"%{city}%")
    if bedrooms is not None:
        q = q.eq("bedrooms", bedrooms)
    results = q.order("created_at", desc=True).execute().data or []
    return [_normalize_listing_media(item) for item in results]


@router.get("/{listing_id}")
async def get_listing(listing_id: str) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("listings").select("*").eq("id", listing_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Listing not found")
    return _normalize_listing_media(res.data)


@router.post("/", status_code=201)
async def create_listing(payload: ListingIn) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("listings").insert(payload.model_dump(exclude_none=True)).execute()
    return res.data[0]


@router.put("/{listing_id}")
async def update_listing(listing_id: str, payload: ListingIn) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("listings").update(payload.model_dump(exclude_none=True)).eq("id", listing_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Listing not found")
    return res.data[0]


@router.delete("/{listing_id}", status_code=204)
async def delete_listing(listing_id: str) -> None:
    sb = get_supabase()
    sb.table("listings").delete().eq("id", listing_id).execute()


@router.post("/{listing_id}/view", status_code=204)
async def record_listing_view(listing_id: str) -> None:
    sb = get_supabase()
    existing = sb.table("listings").select("views_count").eq("id", listing_id).single().execute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Listing not found")
    current = existing.data.get("views_count") or 0
    sb.table("listings").update({"views_count": current + 1}).eq("id", listing_id).execute()


@router.post("/{listing_id}/inquiries", status_code=201)
async def create_listing_inquiry(listing_id: str, payload: InquiryIn) -> dict[str, Any]:
    sb = get_supabase()
    listing = sb.table("listings").select("id").eq("id", listing_id).single().execute()
    if not listing.data:
        raise HTTPException(status_code=404, detail="Listing not found")
    inquiry = {
        **payload.model_dump(exclude_none=True),
        "listing_id": listing_id,
        "status": "new",
    }
    res = sb.table("listing_inquiries").insert(inquiry).execute()
    return res.data[0]


@router.get("/{listing_id}/inquiries")
async def list_listing_inquiries(listing_id: str) -> list[dict[str, Any]]:
    sb = get_supabase()
    return (
        sb.table("listing_inquiries")
        .select("*")
        .eq("listing_id", listing_id)
        .order("created_at", desc=True)
        .execute()
        .data
        or []
    )


@router.post("/inquiries/{inquiry_id}/convert")
async def convert_inquiry(inquiry_id: str) -> dict[str, Any]:
    sb = get_supabase()
    res = (
        sb.table("listing_inquiries")
        .update({"status": "converted", "converted_at": "now()"})
        .eq("id", inquiry_id)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="Inquiry not found")
    return res.data[0]


@router.get("/{listing_id}/analytics")
async def get_listing_analytics(listing_id: str) -> dict[str, Any]:
    sb = get_supabase()
    listing = sb.table("listings").select("views_count").eq("id", listing_id).single().execute()
    if not listing.data:
        raise HTTPException(status_code=404, detail="Listing not found")
    views = listing.data.get("views_count") or 0
    inquiries = (
        sb.table("listing_inquiries")
        .select("id, status")
        .eq("listing_id", listing_id)
        .execute()
        .data
        or []
    )
    count = len(inquiries)
    converted = sum(1 for item in inquiries if item.get("status") == "converted")
    return {
        "listing_id": listing_id,
        "views": views,
        "inquiries": count,
        "conversions": converted,
        "conversion_rate": count > 0 and converted / count or 0,
    }
