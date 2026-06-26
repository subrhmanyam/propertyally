"""Global search — queries properties, tenants, and maintenance requests."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, Query

from db import get_supabase

router = APIRouter()


@router.get("/")
async def search(q: str = Query(..., min_length=1, max_length=100)) -> dict[str, Any]:
    """
    Full-text search across leasing_units, tenants, and maintenance_requests.
    Returns up to 5 results per category.
    """
    sb = get_supabase()
    term = q.strip().lower()

    # ── Properties ──────────────────────────────────────────────────────────
    units = (
        sb.table("leasing_units")
        .select("id,name,company_name,category,floor,status")
        .or_(f"name.ilike.%{term}%,company_name.ilike.%{term}%,category.ilike.%{term}%")
        .limit(5)
        .execute()
        .data or []
    )

    # ── Tenants ──────────────────────────────────────────────────────────────
    tenants = (
        sb.table("tenants")
        .select("id,first_name,last_name,email,phone,status,leasing_unit_id")
        .or_(f"first_name.ilike.%{term}%,last_name.ilike.%{term}%,email.ilike.%{term}%,phone.ilike.%{term}%")
        .limit(5)
        .execute()
        .data or []
    )

    # ── Maintenance ───────────────────────────────────────────────────────────
    maintenance = (
        sb.table("maintenance_requests")
        .select("id,title,status,priority,leasing_unit_id")
        .or_(f"title.ilike.%{term}%,category.ilike.%{term}%")
        .limit(5)
        .execute()
        .data or []
    )

    return {
        "query": q,
        "properties": [
            {
                "id": u["id"],
                "type": "property",
                "title": u.get("name", ""),
                "subtitle": f"{u.get('company_name', '')} · {u.get('category', '')} · {u.get('floor', '')}",
                "status": u.get("status", ""),
                "route": "/properties",
            }
            for u in units
        ],
        "tenants": [
            {
                "id": t["id"],
                "type": "tenant",
                "title": f"{t.get('first_name', '')} {t.get('last_name', '')}".strip(),
                "subtitle": t.get("email") or t.get("phone") or "",
                "status": t.get("status", ""),
                "route": f"/tenants/{t['id']}",
            }
            for t in tenants
        ],
        "maintenance": [
            {
                "id": m["id"],
                "type": "maintenance",
                "title": m.get("title", ""),
                "subtitle": f"{m.get('priority', '')} · {m.get('status', '')}",
                "status": m.get("status", ""),
                "route": "/maintenance",
            }
            for m in maintenance
        ],
    }
