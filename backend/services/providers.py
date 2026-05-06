"""
Notification provider abstractions and implementations.

Switching providers requires only one env-var change — no code edits.

  EMAIL_PROVIDER   = "sendgrid" (default) | "aws_ses"
  SMS_PROVIDER     = "msg91"    (default) | "twilio"

Env vars per provider
─────────────────────
SendGrid:
  SENDGRID_API_KEY
  SENDGRID_FROM_EMAIL   (default: noreply@bogineni.com)
  SENDGRID_FROM_NAME    (default: Bogineni Group)

AWS SES:
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
  AWS_REGION            (default: ap-south-1)
  SES_FROM_EMAIL        (default: noreply@bogineni.com)
  SES_FROM_NAME         (default: Bogineni Group)

MSG91:
  MSG91_AUTH_KEY
  MSG91_SENDER_ID       (default: BOGINI — 6 chars, DLT-registered)
  MSG91_ROUTE           (default: 4 — transactional)

Twilio SMS:
  TWILIO_ACCOUNT_SID
  TWILIO_AUTH_TOKEN
  TWILIO_PHONE_NUMBER   (E.164, e.g. +14155552671)

Twilio WhatsApp:
  TWILIO_ACCOUNT_SID
  TWILIO_AUTH_TOKEN
  TWILIO_WHATSAPP_NUMBER (e.g. whatsapp:+14155238886)
"""

from __future__ import annotations

import asyncio
import logging
import os
from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum
from typing import Any

import httpx

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Shared value objects (imported by notification_service.py)
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


# ---------------------------------------------------------------------------
# Abstract bases
# ---------------------------------------------------------------------------

class EmailProvider(ABC):
    """Delivers a single transactional email."""

    @property
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    async def send(
        self,
        *,
        to_email: str,
        to_name: str,
        subject: str,
        html_body: str,
        text_body: str | None,
    ) -> DeliveryResult: ...


class SmsProvider(ABC):
    """Delivers a single SMS."""

    @property
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    async def send(self, *, to_phone: str, body: str) -> DeliveryResult: ...


class WhatsAppProvider(ABC):
    """Delivers a single WhatsApp message."""

    @property
    @abstractmethod
    def name(self) -> str: ...

    @abstractmethod
    async def send(self, *, to_phone: str, body: str) -> DeliveryResult: ...


# ---------------------------------------------------------------------------
# Email — SendGrid
# ---------------------------------------------------------------------------

class SendGridEmailProvider(EmailProvider):
    """Sends email via SendGrid v3 REST API."""

    @property
    def name(self) -> str:
        return "sendgrid"

    def __init__(self) -> None:
        self._api_key = os.getenv("SENDGRID_API_KEY", "")
        self._from_email = os.getenv("SENDGRID_FROM_EMAIL", "noreply@bogineni.com")
        self._from_name = os.getenv("SENDGRID_FROM_NAME", "Bogineni Group")

    async def send(
        self,
        *,
        to_email: str,
        to_name: str,
        subject: str,
        html_body: str,
        text_body: str | None,
    ) -> DeliveryResult:
        if not self._api_key:
            logger.warning("[sendgrid] SENDGRID_API_KEY not set — skipping %s", to_email)
            return DeliveryResult(Channel.EMAIL, DeliveryStatus.SKIPPED,
                                  error="SENDGRID_API_KEY not configured")

        content: list[dict] = []
        if text_body:
            content.append({"type": "text/plain", "value": text_body})
        content.append({"type": "text/html", "value": html_body})

        payload = {
            "personalizations": [{"to": [{"email": to_email, "name": to_name}]}],
            "from": {"email": self._from_email, "name": self._from_name},
            "subject": subject,
            "content": content,
        }
        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.post(
                    "https://api.sendgrid.com/v3/mail/send",
                    json=payload,
                    headers={"Authorization": f"Bearer {self._api_key}"},
                )
        except httpx.RequestError as exc:
            return DeliveryResult(Channel.EMAIL, DeliveryStatus.FAILED, error=str(exc))

        if resp.status_code in (200, 202):
            ref = resp.headers.get("X-Message-Id", "")
            logger.info("[sendgrid] Sent to %s — msg_id=%s", to_email, ref)
            return DeliveryResult(Channel.EMAIL, DeliveryStatus.SENT, provider_ref=ref)

        logger.error("[sendgrid] %s: %s", resp.status_code, resp.text[:200])
        return DeliveryResult(Channel.EMAIL, DeliveryStatus.FAILED,
                              error=f"HTTP {resp.status_code}: {resp.text[:200]}")


# ---------------------------------------------------------------------------
# Email — AWS SES (boto3, run in thread-pool to stay non-blocking)
# ---------------------------------------------------------------------------

class AwsSesEmailProvider(EmailProvider):
    """Sends email via AWS Simple Email Service (boto3)."""

    @property
    def name(self) -> str:
        return "aws_ses"

    def __init__(self) -> None:
        self._from_email = os.getenv("SES_FROM_EMAIL", "noreply@bogineni.com")
        self._from_name = os.getenv("SES_FROM_NAME", "Bogineni Group")
        self._region = os.getenv("AWS_REGION", "ap-south-1")
        # boto3 reads AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY from env automatically.
        # Import lazily so missing boto3 only fails at runtime, not import time.
        self._client: Any = None

    def _get_client(self) -> Any:
        if self._client is None:
            import boto3  # type: ignore[import]
            self._client = boto3.client("ses", region_name=self._region)
        return self._client

    def _send_sync(
        self, to_email: str, to_name: str,
        subject: str, html_body: str, text_body: str | None,
    ) -> DeliveryResult:
        client = self._get_client()
        source = f"{self._from_name} <{self._from_email}>"
        body: dict[str, Any] = {"Html": {"Charset": "UTF-8", "Data": html_body}}
        if text_body:
            body["Text"] = {"Charset": "UTF-8", "Data": text_body}

        try:
            resp = client.send_email(
                Source=source,
                Destination={"ToAddresses": [f"{to_name} <{to_email}>"]},
                Message={
                    "Subject": {"Charset": "UTF-8", "Data": subject},
                    "Body": body,
                },
            )
            msg_id: str = resp.get("MessageId", "")
            logger.info("[aws_ses] Sent to %s — msg_id=%s", to_email, msg_id)
            return DeliveryResult(Channel.EMAIL, DeliveryStatus.SENT, provider_ref=msg_id)
        except Exception as exc:
            logger.error("[aws_ses] Error: %s", exc)
            return DeliveryResult(Channel.EMAIL, DeliveryStatus.FAILED, error=str(exc))

    async def send(
        self,
        *,
        to_email: str,
        to_name: str,
        subject: str,
        html_body: str,
        text_body: str | None,
    ) -> DeliveryResult:
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(
            None,
            lambda: self._send_sync(to_email, to_name, subject, html_body, text_body),
        )


# ---------------------------------------------------------------------------
# SMS — MSG91  (preferred for India)
# ---------------------------------------------------------------------------

class Msg91SmsProvider(SmsProvider):
    """
    Sends SMS via MSG91 v5 API.

    Phone format: E.164 without '+', e.g. 919876543210
    DLT requirements: sender ID and message templates must be pre-registered
    with TRAI via MSG91 dashboard before going live.
    """

    @property
    def name(self) -> str:
        return "msg91"

    def __init__(self) -> None:
        self._auth_key = os.getenv("MSG91_AUTH_KEY", "")
        self._sender = os.getenv("MSG91_SENDER_ID", "BOGINI")   # 6-char DLT sender ID
        self._route = os.getenv("MSG91_ROUTE", "4")              # 4 = transactional

    @staticmethod
    def _normalize(phone: str) -> str:
        """Strip '+' and leading zeros; ensure country code present."""
        digits = phone.lstrip("+").lstrip("0")
        # If no country code prefix (10-digit India number), prepend 91
        if len(digits) == 10:
            digits = f"91{digits}"
        return digits

    async def send(self, *, to_phone: str, body: str) -> DeliveryResult:
        if not self._auth_key:
            logger.warning("[msg91] MSG91_AUTH_KEY not set — skipping %s", to_phone)
            return DeliveryResult(Channel.SMS, DeliveryStatus.SKIPPED,
                                  error="MSG91_AUTH_KEY not configured")

        number = self._normalize(to_phone)
        payload = {
            "sender": self._sender,
            "route": self._route,
            "country": "91",
            "sms": [{"message": body, "to": [number]}],
        }
        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.post(
                    "https://api.msg91.com/api/v5/message/",
                    json=payload,
                    headers={"authkey": self._auth_key, "Content-Type": "application/json"},
                )
        except httpx.RequestError as exc:
            return DeliveryResult(Channel.SMS, DeliveryStatus.FAILED, error=str(exc))

        data = resp.json()
        if data.get("type") == "success":
            ref = str(data.get("request_id", ""))
            logger.info("[msg91] SMS sent to %s — request_id=%s", to_phone, ref)
            return DeliveryResult(Channel.SMS, DeliveryStatus.SENT, provider_ref=ref)

        err = data.get("message") or resp.text[:200]
        logger.error("[msg91] %s: %s", resp.status_code, err)
        return DeliveryResult(Channel.SMS, DeliveryStatus.FAILED, error=err)


# ---------------------------------------------------------------------------
# SMS — Twilio  (fallback / international)
# ---------------------------------------------------------------------------

class TwilioSmsProvider(SmsProvider):
    """Sends SMS via Twilio Messages API."""

    @property
    def name(self) -> str:
        return "twilio"

    def __init__(self) -> None:
        self._sid = os.getenv("TWILIO_ACCOUNT_SID", "")
        self._token = os.getenv("TWILIO_AUTH_TOKEN", "")
        self._from_phone = os.getenv("TWILIO_PHONE_NUMBER", "")

    async def send(self, *, to_phone: str, body: str) -> DeliveryResult:
        if not (self._sid and self._token and self._from_phone):
            logger.warning("[twilio_sms] Credentials not set — skipping %s", to_phone)
            return DeliveryResult(Channel.SMS, DeliveryStatus.SKIPPED,
                                  error="Twilio SMS credentials not configured")

        url = f"https://api.twilio.com/2010-04-01/Accounts/{self._sid}/Messages.json"
        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.post(
                    url,
                    data={"To": to_phone, "From": self._from_phone, "Body": body},
                    auth=(self._sid, self._token),
                )
        except httpx.RequestError as exc:
            return DeliveryResult(Channel.SMS, DeliveryStatus.FAILED, error=str(exc))

        data = resp.json()
        if resp.status_code == 201:
            logger.info("[twilio_sms] Sent to %s — sid=%s", to_phone, data.get("sid"))
            return DeliveryResult(Channel.SMS, DeliveryStatus.SENT,
                                  provider_ref=data.get("sid"))

        err = data.get("message") or resp.text[:200]
        logger.error("[twilio_sms] %s: %s", resp.status_code, err)
        return DeliveryResult(Channel.SMS, DeliveryStatus.FAILED, error=err)


# ---------------------------------------------------------------------------
# WhatsApp — Twilio
# ---------------------------------------------------------------------------

class TwilioWhatsAppProvider(WhatsAppProvider):
    """
    Sends WhatsApp via Twilio WhatsApp Business API.

    Sandbox: recipient must opt-in at https://www.twilio.com/console/sms/whatsapp/sandbox
    Production: requires approved WhatsApp Business sender from Twilio.
    """

    @property
    def name(self) -> str:
        return "twilio_whatsapp"

    def __init__(self) -> None:
        self._sid = os.getenv("TWILIO_ACCOUNT_SID", "")
        self._token = os.getenv("TWILIO_AUTH_TOKEN", "")
        self._from_wa = os.getenv("TWILIO_WHATSAPP_NUMBER", "")  # whatsapp:+14155238886

    async def send(self, *, to_phone: str, body: str) -> DeliveryResult:
        if not (self._sid and self._token and self._from_wa):
            logger.warning("[twilio_wa] Credentials not set — skipping %s", to_phone)
            return DeliveryResult(Channel.WHATSAPP, DeliveryStatus.SKIPPED,
                                  error="Twilio WhatsApp credentials not configured")

        to_wa = to_phone if to_phone.startswith("whatsapp:") else f"whatsapp:{to_phone}"
        url = f"https://api.twilio.com/2010-04-01/Accounts/{self._sid}/Messages.json"

        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.post(
                    url,
                    data={"To": to_wa, "From": self._from_wa, "Body": body},
                    auth=(self._sid, self._token),
                )
        except httpx.RequestError as exc:
            return DeliveryResult(Channel.WHATSAPP, DeliveryStatus.FAILED, error=str(exc))

        data = resp.json()
        if resp.status_code == 201:
            logger.info("[twilio_wa] Sent to %s — sid=%s", to_phone, data.get("sid"))
            return DeliveryResult(Channel.WHATSAPP, DeliveryStatus.SENT,
                                  provider_ref=data.get("sid"))

        err = data.get("message") or resp.text[:200]
        logger.error("[twilio_wa] %s: %s", resp.status_code, err)
        return DeliveryResult(Channel.WHATSAPP, DeliveryStatus.FAILED, error=err)


# ---------------------------------------------------------------------------
# Provider factories  (read EMAIL_PROVIDER / SMS_PROVIDER env vars)
# ---------------------------------------------------------------------------

def make_email_provider() -> EmailProvider:
    """
    Returns the configured email provider.
    Set EMAIL_PROVIDER=aws_ses to use AWS SES; defaults to SendGrid.
    """
    choice = os.getenv("EMAIL_PROVIDER", "sendgrid").lower()
    if choice == "aws_ses":
        logger.info("Email provider: AWS SES (ap-south-1)")
        return AwsSesEmailProvider()
    logger.info("Email provider: SendGrid")
    return SendGridEmailProvider()


def make_sms_provider() -> SmsProvider:
    """
    Returns the configured SMS provider.
    Set SMS_PROVIDER=twilio to use Twilio; defaults to MSG91 (India).
    """
    choice = os.getenv("SMS_PROVIDER", "msg91").lower()
    if choice == "twilio":
        logger.info("SMS provider: Twilio")
        return TwilioSmsProvider()
    logger.info("SMS provider: MSG91")
    return Msg91SmsProvider()


def make_whatsapp_provider() -> WhatsAppProvider:
    """WhatsApp is always Twilio for now."""
    logger.info("WhatsApp provider: Twilio")
    return TwilioWhatsAppProvider()
