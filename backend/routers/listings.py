"""Listings router — public-facing property adverts."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from db import get_supabase

router = APIRouter()


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
    features: list[str] = []


@router.get("/")
async def list_listings(published_only: bool = Query(False)) -> list[dict[str, Any]]:
    sb = get_supabase()
    q = sb.table("listings").select("*")
    if published_only:
        q = q.eq("is_published", True)
    return q.order("created_at", desc=True).execute().data or []


@router.get("/{listing_id}")
async def get_listing(listing_id: str) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("listings").select("*").eq("id", listing_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Listing not found")
    return res.data


@router.post("/", status_code=201)
async def create_listing(payload: ListingIn) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("listings").insert(payload.model_dump()).execute()
    return res.data[0]


@router.put("/{listing_id}")
async def update_listing(listing_id: str, payload: ListingIn) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("listings").update(payload.model_dump()).eq("id", listing_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Listing not found")
    return res.data[0]


@router.delete("/{listing_id}", status_code=204)
async def delete_listing(listing_id: str) -> None:
    sb = get_supabase()
    sb.table("listings").delete().eq("id", listing_id).execute()
