"""Listing Agent API router.

Endpoints:
  POST /api/v1/listing-agent/trigger/{unit_id}   — manually trigger agent for a unit
  GET  /api/v1/listing-agent/posts/{listing_id}  — get all platform posts for a listing
  POST /api/v1/listing-agent/retry/{post_id}     — retry a failed post (reuses stored content)
  GET  /api/v1/listing-agent/status              — dashboard counts by status
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, BackgroundTasks, HTTPException
from pydantic import BaseModel

from agents.listing_agent import run_listing_agent
from db import get_supabase
from platforms.posters import get_poster
from platforms.registry import PLATFORM_REGISTRY, get_platforms_for_category

logger = logging.getLogger(__name__)
router = APIRouter()


class TriggerRequest(BaseModel):
    platform_keys: list[str]


@router.get("/platforms", summary="List all available platforms")
async def list_platforms():
    return [
        {
            "key": key,
            "name": cfg["name"],
            "api_type": cfg["api_type"],
            "active": cfg["active"],
        }
        for key, cfg in PLATFORM_REGISTRY.items()
        if cfg["active"]
    ]


@router.get("/platforms/{unit_id}", summary="List platforms relevant for a unit's category")
async def platforms_for_unit(unit_id: str):
    sb = get_supabase()

    # Use limit(1) instead of single() so 0 rows returns [] not an exception
    unit_resp = sb.table("leasing_units").select("id, name, category").eq("id", unit_id).limit(1).execute()
    unit = (unit_resp.data or [None])[0]

    if unit:
        # Unit found in DB — return platforms relevant to its category
        relevant_keys = get_platforms_for_category(unit.get("category", ""))
    else:
        # Unit not in DB yet (mock data / empty DB) — return all active platforms
        relevant_keys = [k for k, v in PLATFORM_REGISTRY.items() if v["active"]]

    return [
        {
            "key": key,
            "name": PLATFORM_REGISTRY[key]["name"],
            "api_type": PLATFORM_REGISTRY[key]["api_type"],
            "active": PLATFORM_REGISTRY[key]["active"],
        }
        for key in relevant_keys
    ]


@router.post("/trigger/{unit_id}", summary="Trigger listing agent for selected platforms")
async def trigger_agent(unit_id: str, body: TriggerRequest, background_tasks: BackgroundTasks):
    sb = get_supabase()
    unit_resp = sb.table("leasing_units").select("id, name, status").eq("id", unit_id).limit(1).execute()
    if not (unit_resp.data):
        raise HTTPException(status_code=404, detail="Unit not found")
    if not body.platform_keys:
        raise HTTPException(status_code=400, detail="platform_keys must not be empty")

    background_tasks.add_task(run_listing_agent, unit_id, body.platform_keys)
    return {
        "message": "Agent triggered",
        "unit_id": unit_id,
        "unit_name": unit_resp.data[0].get("name"),
        "platforms": body.platform_keys,
    }


@router.get("/posts/{listing_id}", summary="Get platform posts for a listing")
async def get_platform_posts(listing_id: str):
    sb = get_supabase()
    resp = (
        sb.table("listing_platform_posts")
        .select("*")
        .eq("listing_id", listing_id)
        .order("created_at")
        .execute()
    )
    posts = resp.data or []
    for post in posts:
        pk = post.get("platform_key", "")
        post["platform_name"] = PLATFORM_REGISTRY.get(pk, {}).get("name", pk)
    return posts


@router.post("/retry/{post_id}", summary="Retry a failed platform post")
async def retry_post(post_id: str, background_tasks: BackgroundTasks):
    sb = get_supabase()
    post_resp = sb.table("listing_platform_posts").select("*").eq("id", post_id).single().execute()
    if not post_resp.data:
        raise HTTPException(status_code=404, detail="Platform post not found")

    post = post_resp.data
    if post["status"] not in ("failed", "manual_required", "pending"):
        raise HTTPException(status_code=400, detail=f"Cannot retry post with status '{post['status']}'")

    background_tasks.add_task(_retry_post_task, post_id, post)
    return {"message": "Retry queued", "post_id": post_id, "platform": post.get("platform_key")}


async def _retry_post_task(post_id: str, post: dict):
    sb = get_supabase()
    now = datetime.now(tz=timezone.utc).isoformat()
    pk = post["platform_key"]

    # Fetch the associated listing
    listing_resp = sb.table("listings").select("*").eq("id", post["listing_id"]).single().execute()
    if not listing_resp.data:
        logger.error("retry_post: listing %s not found", post["listing_id"])
        return

    listing = listing_resp.data
    content = {
        "title": post.get("platform_title", ""),
        "description": post.get("platform_desc", ""),
    }

    sb.table("listing_platform_posts").update(
        {"status": "posting", "last_attempted_at": now}
    ).eq("id", post_id).execute()

    poster = get_poster(pk)
    result = await poster.post(listing, content)

    config = PLATFORM_REGISTRY.get(pk, {})
    if config.get("api_type") == "manual":
        final_status = "manual_required"
    elif result.get("error_message"):
        final_status = "failed"
    else:
        final_status = "posted"

    update_fields: dict = {"status": final_status, "last_attempted_at": now}
    if final_status == "posted":
        update_fields["external_id"] = result.get("external_id")
        update_fields["external_url"] = result.get("external_url")
        update_fields["posted_at"] = now
        update_fields["error_message"] = None
    elif final_status == "failed":
        update_fields["error_message"] = result.get("error_message")

    sb.table("listing_platform_posts").update(update_fields).eq("id", post_id).execute()
    logger.info("retry_post: post_id=%s platform=%s status=%s", post_id, pk, final_status)


@router.get("/status", summary="Dashboard counts by posting status")
async def agent_status():
    sb = get_supabase()
    resp = sb.table("listing_platform_posts").select("status").execute()
    rows = resp.data or []
    counts: dict[str, int] = {}
    for row in rows:
        s = row.get("status", "unknown")
        counts[s] = counts.get(s, 0) + 1
    return {
        "total": len(rows),
        "by_status": counts,
        "platforms": {
            k: v["name"] for k, v in PLATFORM_REGISTRY.items()
        },
    }
