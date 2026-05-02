"""
Unified notification service — Email (SendGrid), SMS (Twilio), WhatsApp (Twilio), In-app.

Env vars required:
    SENDGRID_API_KEY         — SendGrid API key
    SENDGRID_FROM_EMAIL      — verified sender address  (default: noreply@bogineni.com)
    SENDGRID_FROM_NAME       — sender display name       (default: Bogineni Group)
    TWILIO_ACCOUNT_SID       — Twilio account SID
    TWILIO_AUTH_TOKEN        — Twilio auth token
    TWILIO_PHONE_NUMBER      — E.164 Twilio phone for SMS  (e.g. +14155552671)
    TWILIO_WHATSAPP_NUMBER   — Twilio WhatsApp sender      (e.g. whatsapp:+14155238886)

Any missing credentials cause the corresponding channel to be skipped gracefully.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass, field
from enum import Enum
from typing import Any

import httpx

from db import get_supabase

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Value objects
# ---------------------------------------------------------------------------

class Channel(str, Enum):
    EMAIL = "email"
    SMS = "sms"
    WHATSAPP = "whatsapp"
    IN_APP = "in_app"


class DeliveryStatus(str, Enum):
    SENT = "sent"
    FAILED = "failed"
    SKIPPED = "skipped"


@dataclass
class DeliveryResult:
    channel: Channel
    status: DeliveryStatus
    provider_ref: str | None = None
    error: str | None = None

    def as_dict(self) -> dict[str, Any]:
        return {
            "channel": self.channel.value,
            "status": self.status.value,
            "provider_ref": self.provider_ref,
            "error": self.error,
        }


@dataclass
class MultiDeliveryResult:
    results: list[DeliveryResult] = field(default_factory=list)

    def add(self, r: DeliveryResult) -> None:
        self.results.append(r)

    @property
    def any_sent(self) -> bool:
        return any(r.status == DeliveryStatus.SENT for r in self.results)

    def as_dict(self) -> dict[str, Any]:
        return {
            "any_sent": self.any_sent,
            "results": [r.as_dict() for r in self.results],
        }


# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------

class NotificationService:
    """Delivers notifications across Email, SMS, WhatsApp, and in-app channels."""

    def __init__(self) -> None:
        self._sg_key = os.getenv("SENDGRID_API_KEY", "")
        self._sg_from = os.getenv("SENDGRID_FROM_EMAIL", "noreply@bogineni.com")
        self._sg_name = os.getenv("SENDGRID_FROM_NAME", "Bogineni Group")

        self._tw_sid = os.getenv("TWILIO_ACCOUNT_SID", "")
        self._tw_token = os.getenv("TWILIO_AUTH_TOKEN", "")
        self._tw_phone = os.getenv("TWILIO_PHONE_NUMBER", "")
        self._tw_wa = os.getenv("TWILIO_WHATSAPP_NUMBER", "")  # whatsapp:+14155238886

    # ------------------------------------------------------------------
    # Email via SendGrid
    # ------------------------------------------------------------------

    async def send_email(
        self,
        *,
        to_email: str,
        to_name: str = "",
        subject: str,
        html_body: str,
        text_body: str | None = None,
    ) -> DeliveryResult:
        if not self._sg_key:
            logger.warning("SENDGRID_API_KEY not set — skipping email to %s", to_email)
            return DeliveryResult(Channel.EMAIL, DeliveryStatus.SKIPPED,
                                  error="SENDGRID_API_KEY not configured")

        content: list[dict] = []
        if text_body:
            content.append({"type": "text/plain", "value": text_body})
        content.append({"type": "text/html", "value": html_body})

        payload = {
            "personalizations": [{"to": [{"email": to_email, "name": to_name}]}],
            "from": {"email": self._sg_from, "name": self._sg_name},
            "subject": subject,
            "content": content,
        }

        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.post(
                    "https://api.sendgrid.com/v3/mail/send",
                    json=payload,
                    headers={"Authorization": f"Bearer {self._sg_key}"},
                )
        except httpx.RequestError as exc:
            return DeliveryResult(Channel.EMAIL, DeliveryStatus.FAILED, error=str(exc))

        if resp.status_code in (200, 202):
            ref = resp.headers.get("X-Message-Id", "")
            logger.info("Email sent to %s — msg_id=%s", to_email, ref)
            return DeliveryResult(Channel.EMAIL, DeliveryStatus.SENT, provider_ref=ref)

        logger.error("SendGrid error %s: %s", resp.status_code, resp.text[:300])
        return DeliveryResult(Channel.EMAIL, DeliveryStatus.FAILED,
                              error=f"HTTP {resp.status_code}: {resp.text[:200]}")

    # ------------------------------------------------------------------
    # SMS via Twilio
    # ------------------------------------------------------------------

    async def send_sms(
        self,
        *,
        to_phone: str,
        body: str,
    ) -> DeliveryResult:
        if not (self._tw_sid and self._tw_token and self._tw_phone):
            logger.warning("Twilio SMS not configured — skipping SMS to %s", to_phone)
            return DeliveryResult(Channel.SMS, DeliveryStatus.SKIPPED,
                                  error="Twilio SMS credentials not configured")

        url = f"https://api.twilio.com/2010-04-01/Accounts/{self._tw_sid}/Messages.json"
        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.post(
                    url,
                    data={"To": to_phone, "From": self._tw_phone, "Body": body},
                    auth=(self._tw_sid, self._tw_token),
                )
        except httpx.RequestError as exc:
            return DeliveryResult(Channel.SMS, DeliveryStatus.FAILED, error=str(exc))

        result = resp.json()
        if resp.status_code == 201:
            logger.info("SMS sent to %s — sid=%s", to_phone, result.get("sid"))
            return DeliveryResult(Channel.SMS, DeliveryStatus.SENT,
                                  provider_ref=result.get("sid"))

        err = result.get("message") or resp.text[:200]
        logger.error("Twilio SMS error %s: %s", resp.status_code, err)
        return DeliveryResult(Channel.SMS, DeliveryStatus.FAILED, error=err)

    # ------------------------------------------------------------------
    # WhatsApp via Twilio WhatsApp API
    # ------------------------------------------------------------------

    async def send_whatsapp(
        self,
        *,
        to_phone: str,
        body: str,
    ) -> DeliveryResult:
        """
        Send a WhatsApp message via Twilio.

        `to_phone` should be in E.164 format, e.g. +919876543210.
        The Twilio sandbox number must be joined by the recipient first:
          https://www.twilio.com/console/sms/whatsapp/sandbox
        For production, use an approved WhatsApp Business sender.
        """
        if not (self._tw_sid and self._tw_token and self._tw_wa):
            logger.warning("Twilio WhatsApp not configured — skipping WA to %s", to_phone)
            return DeliveryResult(Channel.WHATSAPP, DeliveryStatus.SKIPPED,
                                  error="Twilio WhatsApp credentials not configured")

        to_wa = to_phone if to_phone.startswith("whatsapp:") else f"whatsapp:{to_phone}"
        url = f"https://api.twilio.com/2010-04-01/Accounts/{self._tw_sid}/Messages.json"

        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.post(
                    url,
                    data={"To": to_wa, "From": self._tw_wa, "Body": body},
                    auth=(self._tw_sid, self._tw_token),
                )
        except httpx.RequestError as exc:
            return DeliveryResult(Channel.WHATSAPP, DeliveryStatus.FAILED, error=str(exc))

        result = resp.json()
        if resp.status_code == 201:
            logger.info("WhatsApp sent to %s — sid=%s", to_phone, result.get("sid"))
            return DeliveryResult(Channel.WHATSAPP, DeliveryStatus.SENT,
                                  provider_ref=result.get("sid"))

        err = result.get("message") or resp.text[:200]
        logger.error("Twilio WA error %s: %s", resp.status_code, err)
        return DeliveryResult(Channel.WHATSAPP, DeliveryStatus.FAILED, error=err)

    # ------------------------------------------------------------------
    # In-app notification (persisted to Supabase)
    # ------------------------------------------------------------------

    def send_in_app(
        self,
        *,
        user_id: str | None,
        title: str,
        body: str,
        type: str = "info",
        action_url: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> DeliveryResult:
        sb = get_supabase()
        row: dict[str, Any] = {
            "user_id": user_id,
            "title": title,
            "body": body,
            "type": type,
            "action_url": action_url,
            "metadata": metadata or {},
            "is_read": False,
        }
        try:
            res = sb.table("notifications").insert(row).execute()
            ref = res.data[0]["id"] if res.data else None
            return DeliveryResult(Channel.IN_APP, DeliveryStatus.SENT, provider_ref=ref)
        except Exception as exc:
            logger.error("In-app insert failed: %s", exc)
            return DeliveryResult(Channel.IN_APP, DeliveryStatus.FAILED, error=str(exc))

    # ------------------------------------------------------------------
    # Multi-channel dispatch
    # ------------------------------------------------------------------

    async def dispatch(
        self,
        *,
        channels: list[Channel],
        # Email fields
        to_email: str | None = None,
        to_name: str = "",
        subject: str = "",
        html_body: str = "",
        text_body: str | None = None,
        # SMS / WhatsApp fields
        to_phone: str | None = None,
        sms_body: str = "",
        whatsapp_body: str = "",
        # In-app fields
        user_id: str | None = None,
        in_app_title: str = "",
        in_app_body: str = "",
        in_app_type: str = "info",
        action_url: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> MultiDeliveryResult:
        """Send across all specified channels concurrently."""
        import asyncio

        result = MultiDeliveryResult()
        tasks = []

        if Channel.EMAIL in channels and to_email:
            tasks.append(self.send_email(
                to_email=to_email, to_name=to_name,
                subject=subject, html_body=html_body, text_body=text_body,
            ))

        if Channel.SMS in channels and to_phone:
            tasks.append(self.send_sms(to_phone=to_phone, body=sms_body or text_body or ""))

        if Channel.WHATSAPP in channels and to_phone:
            tasks.append(self.send_whatsapp(to_phone=to_phone, body=whatsapp_body or sms_body or ""))

        async_results = await asyncio.gather(*tasks, return_exceptions=True)
        for r in async_results:
            if isinstance(r, Exception):
                logger.error("Dispatch task raised: %s", r)
            else:
                result.add(r)

        if Channel.IN_APP in channels:
            result.add(self.send_in_app(
                user_id=user_id,
                title=in_app_title or subject,
                body=in_app_body or text_body or "",
                type=in_app_type,
                action_url=action_url,
                metadata=metadata,
            ))

        return result


# ---------------------------------------------------------------------------
# Module-level singleton
# ---------------------------------------------------------------------------

_service: NotificationService | None = None


def get_notification_service() -> NotificationService:
    global _service
    if _service is None:
        _service = NotificationService()
    return _service
