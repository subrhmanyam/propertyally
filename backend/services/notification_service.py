"""
NotificationService — orchestrates Email, SMS, WhatsApp, and in-app channels.

Providers are injected at construction time (or auto-created from env vars).
Swap providers without touching this file: set EMAIL_PROVIDER / SMS_PROVIDER.

    EMAIL_PROVIDER = "sendgrid" (default) | "aws_ses"
    SMS_PROVIDER   = "msg91"    (default) | "twilio"

Usage
─────
    svc = get_notification_service()          # singleton, auto-configured

    # single channel
    await svc.send_email(to_email="x@y.com", subject="Hi", html_body="<p>Hi</p>")
    await svc.send_sms(to_phone="+919876543210", body="Hello!")
    await svc.send_whatsapp(to_phone="+919876543210", body="Hello!")

    # multi-channel in one call (runs concurrently)
    result = await svc.dispatch(
        channels=[Channel.EMAIL, Channel.SMS, Channel.WHATSAPP],
        to_email="x@y.com", to_name="Ramesh", subject="Invoice",
        html_body="<p>…</p>", text_body="…",
        to_phone="+919876543210", sms_body="…", whatsapp_body="…",
    )
"""

from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field
from typing import Any

from db import get_supabase
from services.providers import (
    Channel, DeliveryResult, DeliveryStatus,
    EmailProvider, SmsProvider, WhatsAppProvider,
    make_email_provider, make_sms_provider, make_whatsapp_provider,
)

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Multi-channel result wrapper
# ---------------------------------------------------------------------------

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
    """
    Orchestrates notification delivery across multiple channels.

    Providers are injected — pass custom instances for testing or
    leave None to auto-create from env vars via the factory functions.
    """

    def __init__(
        self,
        email_provider: EmailProvider | None = None,
        sms_provider: SmsProvider | None = None,
        whatsapp_provider: WhatsAppProvider | None = None,
    ) -> None:
        self._email = email_provider or make_email_provider()
        self._sms = sms_provider or make_sms_provider()
        self._whatsapp = whatsapp_provider or make_whatsapp_provider()

    # ------------------------------------------------------------------
    # Single-channel sends (thin delegation to the injected provider)
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
        return await self._email.send(
            to_email=to_email, to_name=to_name,
            subject=subject, html_body=html_body, text_body=text_body,
        )

    async def send_sms(self, *, to_phone: str, body: str) -> DeliveryResult:
        return await self._sms.send(to_phone=to_phone, body=body)

    async def send_whatsapp(self, *, to_phone: str, body: str) -> DeliveryResult:
        return await self._whatsapp.send(to_phone=to_phone, body=body)

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
            logger.error("[in_app] Insert failed: %s", exc)
            return DeliveryResult(Channel.IN_APP, DeliveryStatus.FAILED, error=str(exc))

    # ------------------------------------------------------------------
    # Multi-channel dispatch  (async channels run concurrently)
    # ------------------------------------------------------------------

    async def dispatch(
        self,
        *,
        channels: list[Channel],
        # Email
        to_email: str | None = None,
        to_name: str = "",
        subject: str = "",
        html_body: str = "",
        text_body: str | None = None,
        # SMS / WhatsApp
        to_phone: str | None = None,
        sms_body: str = "",
        whatsapp_body: str = "",
        # In-app
        user_id: str | None = None,
        in_app_title: str = "",
        in_app_body: str = "",
        in_app_type: str = "info",
        action_url: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> MultiDeliveryResult:
        result = MultiDeliveryResult()
        async_tasks = []

        if Channel.EMAIL in channels and to_email:
            async_tasks.append(self.send_email(
                to_email=to_email, to_name=to_name,
                subject=subject, html_body=html_body, text_body=text_body,
            ))

        if Channel.SMS in channels and to_phone:
            async_tasks.append(self.send_sms(
                to_phone=to_phone, body=sms_body or text_body or "",
            ))

        if Channel.WHATSAPP in channels and to_phone:
            async_tasks.append(self.send_whatsapp(
                to_phone=to_phone, body=whatsapp_body or sms_body or "",
            ))

        gathered = await asyncio.gather(*async_tasks, return_exceptions=True)
        for r in gathered:
            if isinstance(r, Exception):
                logger.error("[dispatch] Channel task raised: %s", r)
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

    # ------------------------------------------------------------------
    # Introspection
    # ------------------------------------------------------------------

    def provider_info(self) -> dict[str, str]:
        """Returns the active provider name for each channel — useful for /health."""
        return {
            "email": self._email.name,
            "sms": self._sms.name,
            "whatsapp": self._whatsapp.name,
            "in_app": "supabase",
        }


# ---------------------------------------------------------------------------
# Module-level singleton
# ---------------------------------------------------------------------------

_service: NotificationService | None = None


def get_notification_service() -> NotificationService:
    global _service
    if _service is None:
        _service = NotificationService()
    return _service
