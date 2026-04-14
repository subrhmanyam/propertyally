"""Notifications router."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from db import get_supabase

router = APIRouter()


class NotificationIn(BaseModel):
    user_id: str | None = None
    title: str
    body: str | None = None
    type: str = "info"
    action_url: str | None = None


@router.get("/")
async def list_notifications(user_id: str | None = None) -> list[dict[str, Any]]:
    sb = get_supabase()
    q = sb.table("notifications").select("*")
    if user_id:
        q = q.eq("user_id", user_id)
    return q.order("created_at", desc=True).execute().data or []


@router.post("/", status_code=201)
async def create_notification(payload: NotificationIn) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("notifications").insert(payload.model_dump()).execute()
    return res.data[0]


@router.put("/{notification_id}/read", status_code=200)
async def mark_read(notification_id: str) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("notifications").update({"is_read": True}).eq("id", notification_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Notification not found")
    return res.data[0]


@router.delete("/{notification_id}", status_code=204)
async def delete_notification(notification_id: str) -> None:
    sb = get_supabase()
    sb.table("notifications").delete().eq("id", notification_id).execute()
