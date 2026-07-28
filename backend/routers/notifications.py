"""
Notifications router — Email, SMS, WhatsApp, and in-app notifications.

Endpoints
---------
  In-app inbox:
    GET    /                       — list in-app notifications (filter by user_id)
    GET    /unread-count           — badge count
    PUT    /{id}/read              — mark one as read
    PUT    /read-all               — mark all as read for a user
    POST   /                       — create in-app notification directly
    DELETE /{id}                   — delete a notification

  Direct sends:
    POST   /send/email             — send an email
    POST   /send/sms               — send an SMS
    POST   /send/whatsapp          — send a WhatsApp message
    POST   /send/all               — send across multiple channels at once

  Template-driven dispatch:
    POST   /dispatch               — render a named template and send
    GET    /templates              — list available event template types

  Webhooks (Twilio / SendGrid delivery status):
    POST   /webhooks/twilio        — Twilio SMS/WA status callback
    POST   /webhooks/sendgrid      — SendGrid event webhook
"""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from auth_utils import require_any_org_admin
from db import get_supabase
from services.notification_service import (
    get_notification_service,
)
from services.providers import Channel
from services.notification_templates import render as render_template, list_event_types

logger = logging.getLogger(__name__)
router = APIRouter()


# ---------------------------------------------------------------------------
# Request models
# ---------------------------------------------------------------------------

class NotificationIn(BaseModel):
    user_id: str | None = None
    title: str
    body: str | None = None
    type: str = "info"
    action_url: str | None = None
    metadata: dict[str, Any] | None = None


class SendEmailRequest(BaseModel):
    to_email: str
    to_name: str = ""
    subject: str
    html_body: str
    text_body: str | None = None


class SendSmsRequest(BaseModel):
    to_phone: str
    body: str


class SendWhatsAppRequest(BaseModel):
    to_phone: str
    body: str


class SendAllRequest(BaseModel):
    """Send across multiple channels in a single call."""
    channels: list[str]                 # ["email", "sms", "whatsapp", "in_app"]
    # Email
    to_email: str | None = None
    to_name: str = ""
    subject: str = ""
    html_body: str = ""
    text_body: str | None = None
    # SMS / WhatsApp
    to_phone: str | None = None
    sms_body: str = ""
    whatsapp_body: str = ""
    # In-app
    user_id: str | None = None
    in_app_title: str = ""
    in_app_body: str = ""
    in_app_type: str = "info"
    action_url: str | None = None
    metadata: dict[str, Any] | None = None


class DispatchRequest(BaseModel):
    """Render a named event template and send."""
    event_type: str
    channels: list[str]
    # Recipient
    to_email: str | None = None
    to_name: str = ""
    to_phone: str | None = None
    user_id: str | None = None
    # Template variables (merged with built-in ones)
    variables: dict[str, Any] = {}


# ---------------------------------------------------------------------------
# In-app inbox
# ---------------------------------------------------------------------------

@router.get("/")
async def list_notifications(user_id: str | None = None) -> list[dict[str, Any]]:
    sb = get_supabase()
    q = sb.table("notifications").select("*")
    if user_id:
        q = q.eq("user_id", user_id)
    return q.order("created_at", desc=True).execute().data or []


@router.get("/unread-count")
async def unread_count(user_id: str) -> dict[str, int]:
    sb = get_supabase()
    res = (
        sb.table("notifications")
        .select("id", count="exact")
        .eq("user_id", user_id)
        .eq("is_read", False)
        .execute()
    )
    return {"count": res.count or 0}


@router.post("/", status_code=201)
async def create_notification(user_id: str, payload: NotificationIn) -> dict[str, Any]:
    require_any_org_admin(get_supabase(), user_id)
    svc = get_notification_service()
    result = svc.send_in_app(
        user_id=payload.user_id,
        title=payload.title,
        body=payload.body or "",
        type=payload.type,
        action_url=payload.action_url,
        metadata=payload.metadata,
    )
    return result.as_dict()


@router.put("/{notification_id}/read")
async def mark_read(notification_id: str, user_id: str) -> dict[str, Any]:
    sb = get_supabase()
    current = sb.table("notifications").select("user_id").eq("id", notification_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Notification not found")
    if current.data[0].get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="This notification does not belong to you.")
    res = (
        sb.table("notifications")
        .update({"is_read": True})
        .eq("id", notification_id)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="Notification not found")
    return res.data[0]


@router.put("/read-all", status_code=200)
async def mark_all_read(user_id: str) -> dict[str, int]:
    sb = get_supabase()
    res = (
        sb.table("notifications")
        .update({"is_read": True})
        .eq("user_id", user_id)
        .eq("is_read", False)
        .execute()
    )
    return {"updated": len(res.data or [])}


@router.delete("/{notification_id}", status_code=204)
async def delete_notification(notification_id: str, user_id: str) -> None:
    sb = get_supabase()
    current = sb.table("notifications").select("user_id").eq("id", notification_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Notification not found")
    if current.data[0].get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="This notification does not belong to you.")
    sb.table("notifications").delete().eq("id", notification_id).execute()


# ---------------------------------------------------------------------------
# Direct sends
# ---------------------------------------------------------------------------

@router.post("/send/email")
async def send_email(user_id: str, req: SendEmailRequest) -> dict[str, Any]:
    require_any_org_admin(get_supabase(), user_id)
    svc = get_notification_service()
    result = await svc.send_email(
        to_email=req.to_email,
        to_name=req.to_name,
        subject=req.subject,
        html_body=req.html_body,
        text_body=req.text_body,
    )
    return result.as_dict()


@router.post("/send/sms")
async def send_sms(user_id: str, req: SendSmsRequest) -> dict[str, Any]:
    require_any_org_admin(get_supabase(), user_id)
    svc = get_notification_service()
    result = await svc.send_sms(to_phone=req.to_phone, body=req.body)
    return result.as_dict()


@router.post("/send/whatsapp")
async def send_whatsapp(user_id: str, req: SendWhatsAppRequest) -> dict[str, Any]:
    require_any_org_admin(get_supabase(), user_id)
    svc = get_notification_service()
    result = await svc.send_whatsapp(to_phone=req.to_phone, body=req.body)
    return result.as_dict()


@router.post("/send/all")
async def send_all(user_id: str, req: SendAllRequest) -> dict[str, Any]:
    require_any_org_admin(get_supabase(), user_id)
    svc = get_notification_service()
    channels = [Channel(c) for c in req.channels if c in Channel._value2member_map_]
    result = await svc.dispatch(
        channels=channels,
        to_email=req.to_email,
        to_name=req.to_name,
        subject=req.subject,
        html_body=req.html_body,
        text_body=req.text_body,
        to_phone=req.to_phone,
        sms_body=req.sms_body,
        whatsapp_body=req.whatsapp_body,
        user_id=req.user_id,
        in_app_title=req.in_app_title,
        in_app_body=req.in_app_body,
        in_app_type=req.in_app_type,
        action_url=req.action_url,
        metadata=req.metadata,
    )
    return result.as_dict()


# ---------------------------------------------------------------------------
# Template-driven dispatch
# ---------------------------------------------------------------------------

@router.get("/templates")
async def get_templates() -> list[str]:
    return list_event_types()


@router.get("/providers")
async def get_providers() -> dict[str, str]:
    """Returns the active provider for each channel — useful for verifying config."""
    return get_notification_service().provider_info()


@router.post("/dispatch")
async def dispatch_event(user_id: str, req: DispatchRequest) -> dict[str, Any]:
    """
    Render a named event template and send across specified channels.

    Example body:
    {
        "event_type": "invoice_generated",
        "channels": ["email", "whatsapp"],
        "to_email": "tenant@example.com",
        "to_name": "Ramesh Kumar",
        "to_phone": "+919876543210",
        "variables": {
            "tenant_name": "Ramesh Kumar",
            "invoice_no": "286",
            "month": "May 2025",
            "amount": 45000,
            "due_date": "05-Jun-2025",
            "payment_url": "https://pay.bogineni.com/inv/286"
        }
    }
    """
    require_any_org_admin(get_supabase(), user_id)
    try:
        rendered = render_template(req.event_type, **req.variables)
    except KeyError:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown event type '{req.event_type}'. "
                   f"Available: {list_event_types()}"
        )

    channels = [Channel(c) for c in req.channels if c in Channel._value2member_map_]
    if not channels:
        raise HTTPException(status_code=400, detail="No valid channels specified")

    svc = get_notification_service()
    result = await svc.dispatch(
        channels=channels,
        to_email=req.to_email,
        to_name=req.to_name,
        subject=rendered["subject"],
        html_body=rendered["html_body"],
        text_body=rendered["text_body"],
        to_phone=req.to_phone,
        sms_body=rendered["sms_body"],
        whatsapp_body=rendered["whatsapp_body"],
        user_id=req.user_id,
        in_app_title=rendered["subject"],
        in_app_body=rendered["text_body"],
    )
    return {
        "event_type": req.event_type,
        "rendered_subject": rendered["subject"],
        **result.as_dict(),
    }


# ---------------------------------------------------------------------------
# Delivery status webhooks
# ---------------------------------------------------------------------------

@router.post("/webhooks/twilio", include_in_schema=False)
async def twilio_webhook(request: Request) -> dict[str, str]:
    """
    Receives Twilio SMS/WhatsApp delivery status callbacks.
    Configure in Twilio console: Status Callback URL = /api/v1/notifications/webhooks/twilio
    """
    form = await request.form()
    sid = form.get("MessageSid", "")
    status = form.get("MessageStatus", "")
    logger.info("Twilio webhook — sid=%s status=%s", sid, status)
    # Persist delivery status update to Supabase if needed
    return {"received": "ok"}


@router.post("/webhooks/sendgrid", include_in_schema=False)
async def sendgrid_webhook(request: Request) -> dict[str, str]:
    """
    Receives SendGrid event webhooks (delivered, bounce, open, etc.).
    Configure in SendGrid: Settings → Mail Settings → Event Webhook
    """
    try:
        events = await request.json()
    except Exception:
        events = []
    for event in (events if isinstance(events, list) else []):
        logger.info(
            "SendGrid event — email=%s event=%s msg_id=%s",
            event.get("email"), event.get("event"), event.get("sg_message_id"),
        )
    return {"received": "ok"}
