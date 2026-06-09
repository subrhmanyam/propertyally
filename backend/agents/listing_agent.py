"""Listing Agent — orchestrates multi-platform publishing for vacant units.

Flow:
1. Fetch unit + area_entries from Supabase
2. Ensure a listing row exists for the unit
3. Call Claude once to generate platform-optimized content for all relevant platforms
4. For each selected platform: upsert a listing_platform_posts row, then attempt posting
5. Create an in-app notification summarising the result
"""

from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timezone

import anthropic

from db import get_supabase
from platforms.posters import get_poster
from platforms.registry import PLATFORM_REGISTRY

logger = logging.getLogger(__name__)

_SYSTEM_PROMPT = """You are a property listing expert for Bogineni Group, a premium commercial \
real estate portfolio in India. You write compelling, platform-optimized listing content for \
vacant commercial and residential spaces. You know Indian real estate platforms well and adapt \
tone and emphasis for each one. Always respond with valid JSON only — no markdown, no prose."""

_anthropic_client: anthropic.Anthropic | None = None
SUPABASE_LISTING_MEDIA_BUCKET = os.getenv('SUPABASE_LISTING_MEDIA_BUCKET')


def _resolve_media_url(value: str) -> str:
    if not value:
        return value
    if value.startswith('http://') or value.startswith('https://'):
        return value
    if SUPABASE_LISTING_MEDIA_BUCKET:
        clean_value = value.lstrip('/')
        supabase_url = os.getenv('SUPABASE_URL', '').rstrip('/')
        if supabase_url:
            return f"{supabase_url}/storage/v1/object/public/{SUPABASE_LISTING_MEDIA_BUCKET}/{clean_value}"
    return value


def _normalize_listing_media(listing: dict) -> dict:
    normalized = dict(listing)
    normalized['photos'] = [
        _resolve_media_url(photo) for photo in normalized.get('photos', []) or []
    ]
    normalized['video_urls'] = [
        _resolve_media_url(url) for url in normalized.get('video_urls', []) or []
    ]
    normalized['virtual_tour_url'] = _resolve_media_url(normalized.get('virtual_tour_url', '') or '')
    return normalized


def _get_client() -> anthropic.Anthropic:
    global _anthropic_client
    if _anthropic_client is None:
        _anthropic_client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    return _anthropic_client


def _build_areas_summary(area_entries: list[dict]) -> tuple[str, float]:
    parts = []
    total = 0.0
    for entry in area_entries:
        sqft = entry.get("sqft", 0)
        rate = entry.get("rate", 0)
        kind = entry.get("type", "area")
        parts.append(f"{kind.capitalize()}: {sqft:,.0f} sqft @ ₹{rate:,.0f}/sqft/month")
        total += sqft
    return "; ".join(parts) if parts else "Not specified", total


def _build_user_prompt(unit: dict, area_entries: list[dict], platform_keys: list[str]) -> str:
    areas_summary, total_sqft = _build_areas_summary(area_entries)
    monthly_rent = unit.get("monthly_rent") or sum(
        e.get("sqft", 0) * e.get("rate", 0) for e in area_entries
    )

    platform_lines = "\n".join(
        f"- {pk} | {PLATFORM_REGISTRY[pk]['name']} | tone: {PLATFORM_REGISTRY[pk]['tone']}"
        for pk in platform_keys
    )

    return f"""A leasing unit has become vacant. Generate optimized listing content for the \
following real estate platforms.

UNIT DETAILS:
- Name: {unit.get('name', 'N/A')}
- Category: {unit.get('category', 'N/A')}
- Floor: {unit.get('floor', 'N/A')}
- Areas: {areas_summary}
- Total Sq.ft: {total_sqft:,.0f}
- Monthly Rent: ₹{monthly_rent:,.0f}
- Notes: {unit.get('notes') or 'None'}

PLATFORMS TO GENERATE FOR:
{platform_lines}

INSTRUCTIONS:
- For each platform, generate a title (max 80 chars) and description (150–300 words)
- Adapt the tone per platform as specified
- Emphasise relevant features: sq.ft, rent, floor, category-specific advantages
- Use Indian real estate conventions (sq.ft, ₹, prime location, etc.)
- In selected_platforms, include only the platforms that are genuinely relevant for this \
property category — you may exclude platforms that are a poor fit
- Return ONLY valid JSON matching this exact schema:

{{
  "selected_platforms": ["platform_key1", "platform_key2"],
  "platform_content": {{
    "platform_key1": {{
      "title": "...",
      "description": "..."
    }}
  }}
}}"""


async def run_listing_agent(unit_id: str, platform_keys: list[str]) -> dict:
    """Main entry point. Called as a FastAPI background task."""
    sb = get_supabase()
    now = datetime.now(tz=timezone.utc).isoformat()

    # 1. Fetch unit
    unit_resp = sb.table("leasing_units").select("*").eq("id", unit_id).limit(1).execute()
    if not unit_resp.data:
        logger.error("listing_agent: unit %s not found", unit_id)
        return {"error": "unit_not_found"}
    unit = unit_resp.data[0]

    # 2. Fetch area entries
    areas_resp = sb.table("area_entries").select("*").eq("leasing_unit_id", unit_id).execute()
    area_entries: list[dict] = areas_resp.data or []

    # 3. Calculate estimated monthly rent from area entries
    estimated_rent = sum(e.get("sqft", 0) * e.get("rate", 0) for e in area_entries)

    # 4. Ensure a listing row exists
    existing = (
        sb.table("listings")
        .select("id, monthly_rent, contact_email, contact_phone, photos, video_urls, virtual_tour_url, features")
        .eq("leasing_unit_id", unit_id)
        .limit(1)
        .execute()
    )
    if existing.data:
        listing = existing.data[0]
    else:
        new_listing = {
            "leasing_unit_id": unit_id,
            "title": f"{unit.get('category', 'Space')} for Rent — {unit.get('name', '')}",
            "description": "",
            "monthly_rent": estimated_rent,
            "is_published": False,
            "contact_email": unit.get("email") or "",
            "contact_phone": unit.get("contact") or "",
            "photos": [],
            "features": [],
            "video_urls": [],
            "virtual_tour_url": None,
        }
        created = sb.table("listings").insert(new_listing).execute()
        listing = created.data[0]

    listing_id = listing["id"]

    # 5. Use caller-supplied platform keys (user-selected), validated against active registry
    if not platform_keys:
        logger.warning("listing_agent: no platforms provided for unit '%s'", unit_id)
        return {"listing_id": listing_id, "platforms_attempted": 0}

    platform_keys = [k for k in platform_keys if k in PLATFORM_REGISTRY]
    if not platform_keys:
        logger.warning("listing_agent: none of the provided platforms are valid")
        return {"listing_id": listing_id, "platforms_attempted": 0}

    # 6. Call Claude
    try:
        client = _get_client()
        user_prompt = _build_user_prompt(unit, area_entries, platform_keys)
        response = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=2048,
            system=[
                {
                    "type": "text",
                    "text": _SYSTEM_PROMPT,
                    "cache_control": {"type": "ephemeral"},
                }
            ],
            messages=[{"role": "user", "content": user_prompt}],
        )
        raw = response.content[0].text.strip()
        claude_result = json.loads(raw)
    except Exception as exc:
        logger.error("listing_agent: Claude API error for unit %s: %s", unit_id, exc)
        return {"listing_id": listing_id, "error": str(exc)}

    selected = claude_result.get("selected_platforms", platform_keys)
    platform_content: dict = claude_result.get("platform_content", {})

    # 7. Post to each selected platform
    results: list[dict] = []
    for pk in selected:
        content = platform_content.get(pk, {})
        config = PLATFORM_REGISTRY.get(pk, {})

        # Upsert platform post row as 'posting'
        post_row = {
            "listing_id": listing_id,
            "platform_key": pk,
            "status": "posting",
            "platform_title": content.get("title"),
            "platform_desc": content.get("description"),
            "last_attempted_at": now,
        }
        upsert_resp = (
            sb.table("listing_platform_posts")
            .upsert(post_row, on_conflict="listing_id,platform_key")
            .execute()
        )
        post_id = upsert_resp.data[0]["id"]

        # Attempt posting
        poster = get_poster(pk)
        post_result = await poster.post(_normalize_listing_media(listing), content)

        if config.get("api_type") == "manual":
            final_status = "manual_required"
        elif post_result.get("error_message"):
            final_status = "failed"
        else:
            final_status = "posted"

        update_fields: dict = {
            "status": final_status,
            "last_attempted_at": now,
        }
        if final_status == "posted":
            update_fields["external_id"] = post_result.get("external_id")
            update_fields["external_url"] = post_result.get("external_url")
            update_fields["posted_at"] = now
        elif final_status == "failed":
            update_fields["error_message"] = post_result.get("error_message")

        sb.table("listing_platform_posts").update(update_fields).eq("id", post_id).execute()
        results.append({"platform": pk, "status": final_status})
        logger.info("listing_agent: unit=%s platform=%s status=%s", unit_id, pk, final_status)

    # 8. Create in-app notification for admin
    posted_count = sum(1 for r in results if r["status"] == "posted")
    manual_count = sum(1 for r in results if r["status"] == "manual_required")
    failed_count = sum(1 for r in results if r["status"] == "failed")

    notification_body = (
        f"Unit '{unit.get('name')}' published: "
        f"{posted_count} posted, {manual_count} need manual posting, {failed_count} failed."
    )
    try:
        # Notify all admin profiles
        profiles = sb.table("profiles").select("id").execute()
        for profile in (profiles.data or []):
            sb.table("notifications").insert({
                "user_id": profile["id"],
                "title": f"Listing published — {unit.get('name', unit_id)}",
                "body": notification_body,
                "type": "info" if failed_count == 0 else "warning",
                "is_read": False,
            }).execute()
    except Exception as exc:
        logger.warning("listing_agent: failed to create notification: %s", exc)

    # 9. Mark as processed in the queue table (if present)
    try:
        sb.table("listing_agent_queue").update(
            {"processed": True, "processed_at": now}
        ).eq("leasing_unit_id", unit_id).execute()
    except Exception:
        pass

    return {
        "listing_id": listing_id,
        "unit_id": unit_id,
        "platforms_attempted": len(selected),
        "results": results,
    }
