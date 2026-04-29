"""Platform poster classes — one per API type.

RestApiPoster: stubs that log the payload and return a mock ID until real
partner API credentials are obtained from Housing.com / 99acres / MagicBricks.

ManualPoster: marks the post as manual_required so the admin can copy-paste
the Claude-generated content into the platform's web UI.
"""

from __future__ import annotations

import logging
import os
from abc import ABC, abstractmethod
from datetime import datetime, timezone

import httpx

from platforms.registry import PLATFORM_REGISTRY

logger = logging.getLogger(__name__)


class BasePoster(ABC):
    def __init__(self, platform_key: str):
        self.platform_key = platform_key
        self.config = PLATFORM_REGISTRY[platform_key]

    @abstractmethod
    async def post(self, listing: dict, content: dict) -> dict:
        """Post listing to the platform.

        Returns dict with keys: external_id, external_url, error_message
        """


class RestApiPoster(BasePoster):
    """Posts to platforms that have a REST partner API."""

    async def post(self, listing: dict, content: dict) -> dict:
        api_key_env = self.config.get("api_key_env")
        base_url_env = self.config.get("base_url_env")
        api_key = os.getenv(api_key_env, "") if api_key_env else ""
        base_url = os.getenv(base_url_env, "") if base_url_env else ""

        payload = {
            "title": content.get("title", ""),
            "description": content.get("description", ""),
            "monthly_rent": listing.get("monthly_rent", 0),
            "available_from": listing.get("available_from"),
            "contact_email": listing.get("contact_email", ""),
            "contact_phone": listing.get("contact_phone", ""),
            "photos": listing.get("photos", []),
            "features": listing.get("features", []),
        }

        if not api_key or not base_url:
            # Stub mode: no credentials yet — log and return mock success
            logger.info(
                "[%s] STUB POST (no API key) payload=%s",
                self.config["name"],
                payload,
            )
            mock_id = f"stub_{self.platform_key}_{listing.get('id', 'unknown')[:8]}"
            return {
                "external_id": mock_id,
                "external_url": None,
                "error_message": None,
            }

        try:
            async with httpx.AsyncClient(timeout=15) as client:
                resp = await client.post(
                    f"{base_url}/listings",
                    json=payload,
                    headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
                )
                resp.raise_for_status()
                data = resp.json()
                return {
                    "external_id": str(data.get("id") or data.get("listing_id") or ""),
                    "external_url": data.get("url") or data.get("listing_url"),
                    "error_message": None,
                }
        except httpx.HTTPStatusError as exc:
            logger.error("[%s] HTTP error posting listing: %s", self.config["name"], exc)
            return {"external_id": None, "external_url": None, "error_message": str(exc)}
        except Exception as exc:
            logger.error("[%s] Unexpected error posting listing: %s", self.config["name"], exc)
            return {"external_id": None, "external_url": None, "error_message": str(exc)}


class ManualPoster(BasePoster):
    """No API available — marks the post as manual_required."""

    async def post(self, listing: dict, content: dict) -> dict:
        logger.info(
            "[%s] Manual posting required for listing %s",
            self.config["name"],
            listing.get("id"),
        )
        return {"external_id": None, "external_url": None, "error_message": None}


def get_poster(platform_key: str) -> BasePoster:
    config = PLATFORM_REGISTRY.get(platform_key)
    if not config:
        raise ValueError(f"Unknown platform: {platform_key}")
    if config["api_type"] == "rest_api":
        return RestApiPoster(platform_key)
    return ManualPoster(platform_key)
