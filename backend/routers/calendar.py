"""Calendar router — events for lease renewals, rent dues, maintenance, meetings."""

from __future__ import annotations

from datetime import date, datetime, timezone, timedelta
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from auth_utils import require_any_org_admin, require_org_admin_for_unit
from db import get_supabase

router = APIRouter()


def _require_admin(sb, user_id: str, unit_id: str | None) -> None:
    if unit_id:
        require_org_admin_for_unit(sb, user_id, unit_id)
    else:
        require_any_org_admin(sb, user_id)


class EventIn(BaseModel):
    title: str
    description: str | None = None
    event_type: str = "meeting"   # inspection | payment_due | lease_renewal | maintenance | meeting
    start_at: str                  # ISO 8601
    end_at: str | None = None
    all_day: bool = False
    leasing_unit_id: str | None = None
    tenant_id: str | None = None
    created_by: str | None = None


class EventUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    event_type: str | None = None
    start_at: str | None = None
    end_at: str | None = None
    all_day: bool | None = None
    leasing_unit_id: str | None = None
    tenant_id: str | None = None


@router.get("/")
async def list_events(
    start: str | None = Query(None, description="ISO date range start"),
    end: str | None = Query(None, description="ISO date range end"),
    event_type: str | None = None,
    leasing_unit_id: str | None = None,
) -> list[dict[str, Any]]:
    sb = get_supabase()
    q = sb.table("events").select("*").order("start_at", desc=False)
    if start:
        q = q.gte("start_at", start)
    if end:
        q = q.lte("start_at", end)
    if event_type:
        q = q.eq("event_type", event_type)
    if leasing_unit_id:
        q = q.eq("leasing_unit_id", leasing_unit_id)
    return q.execute().data or []


@router.get("/upcoming")
async def upcoming_events(days: int = Query(30, ge=1, le=365)) -> list[dict[str, Any]]:
    sb = get_supabase()
    now = datetime.now(tz=timezone.utc)
    end = now + timedelta(days=days)
    return (
        sb.table("events")
        .select("*")
        .gte("start_at", now.isoformat())
        .lte("start_at", end.isoformat())
        .order("start_at", desc=False)
        .execute()
        .data or []
    )


@router.get("/{event_id}")
async def get_event(event_id: str) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("events").select("*").eq("id", event_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Event not found")
    return res.data


@router.post("/", status_code=201)
async def create_event(user_id: str, payload: EventIn) -> dict[str, Any]:
    sb = get_supabase()
    _require_admin(sb, user_id, payload.leasing_unit_id)
    data = {k: v for k, v in payload.model_dump().items() if v is not None}
    res = sb.table("events").insert(data).execute()
    return res.data[0]


@router.put("/{event_id}")
async def update_event(event_id: str, user_id: str, payload: EventUpdate) -> dict[str, Any]:
    sb = get_supabase()
    updates = {k: v for k, v in payload.model_dump().items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    current = sb.table("events").select("leasing_unit_id").eq("id", event_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Event not found")
    _require_admin(sb, user_id, payload.leasing_unit_id or current.data[0].get("leasing_unit_id"))
    res = sb.table("events").update(updates).eq("id", event_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Event not found")
    return res.data[0]


@router.delete("/{event_id}", status_code=204)
async def delete_event(event_id: str, user_id: str) -> None:
    sb = get_supabase()
    current = sb.table("events").select("leasing_unit_id").eq("id", event_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Event not found")
    _require_admin(sb, user_id, current.data[0].get("leasing_unit_id"))
    sb.table("events").delete().eq("id", event_id).execute()


# ── Auto-generate events from leases and rent schedules ──────────────────────

@router.post("/sync-from-leases", status_code=200)
async def sync_events_from_leases(user_id: str) -> dict[str, Any]:
    """
    Generates calendar events for:
    - Lease expiry (30-day warning)
    - Rent due dates (next 3 months)
    Returns count of events created.
    """
    sb = get_supabase()
    require_any_org_admin(sb, user_id)
    created = 0
    today = date.today()

    # Active leases — create renewal reminders 30 days before end
    leases = (
        sb.table("leases")
        .select("id,tenant_id,leasing_unit_id,end_date,monthly_rent")
        .eq("status", "active")
        .execute()
        .data or []
    )
    for lease in leases:
        end_str = lease.get("end_date", "")
        if not end_str:
            continue
        try:
            end_date = date.fromisoformat(end_str)
        except ValueError:
            continue
        reminder_date = end_date - timedelta(days=30)
        if reminder_date >= today:
            # Upsert-style: check if a renewal event already exists for this lease
            existing = (
                sb.table("events")
                .select("id")
                .eq("event_type", "lease_renewal")
                .eq("leasing_unit_id", lease.get("leasing_unit_id") or "")
                .gte("start_at", reminder_date.isoformat())
                .execute()
                .data or []
            )
            if not existing:
                sb.table("events").insert({
                    "title": "Lease Renewal Due",
                    "description": f"Lease expires on {end_str}. Contact tenant to renew or vacate.",
                    "event_type": "lease_renewal",
                    "start_at": f"{reminder_date.isoformat()}T09:00:00+00:00",
                    "all_day": True,
                    "leasing_unit_id": lease.get("leasing_unit_id"),
                    "tenant_id": lease.get("tenant_id"),
                }).execute()
                created += 1

    # Rent schedules — create payment_due events for next 3 months
    schedules = (
        sb.table("rent_schedules")
        .select("id,lease_id,due_day,amount")
        .eq("is_active", True)
        .execute()
        .data or []
    )
    # Map lease_id → unit_id
    if schedules:
        lease_ids = list({s["lease_id"] for s in schedules})
        lease_rows = (
            sb.table("leases")
            .select("id,leasing_unit_id,tenant_id")
            .in_("id", lease_ids)
            .execute()
            .data or []
        )
        lease_map = {r["id"]: r for r in lease_rows}

        for sched in schedules:
            lease_info = lease_map.get(sched["lease_id"], {})
            unit_id = lease_info.get("leasing_unit_id")
            tenant_id = lease_info.get("tenant_id")
            due_day = sched.get("due_day", 1)
            amount = sched.get("amount", 0)

            for offset in range(3):
                m = today.month + offset
                y = today.year + (m - 1) // 12
                m = ((m - 1) % 12) + 1
                try:
                    due_date = date(y, m, min(due_day, 28))
                except ValueError:
                    continue
                if due_date < today:
                    continue
                existing = (
                    sb.table("events")
                    .select("id")
                    .eq("event_type", "payment_due")
                    .eq("leasing_unit_id", unit_id or "")
                    .gte("start_at", due_date.isoformat())
                    .lte("start_at", due_date.isoformat() + "T23:59:59")
                    .execute()
                    .data or []
                )
                if not existing:
                    sb.table("events").insert({
                        "title": f"Rent Due — ₹{amount:,.0f}",
                        "description": f"Monthly rent of ₹{amount:,.0f} due on {due_day}th.",
                        "event_type": "payment_due",
                        "start_at": f"{due_date.isoformat()}T00:00:00+00:00",
                        "all_day": True,
                        "leasing_unit_id": unit_id,
                        "tenant_id": tenant_id,
                    }).execute()
                    created += 1

    return {"events_created": created}
