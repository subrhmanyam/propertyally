"""Platform registry — config-driven map of supported real estate platforms.

Adding a new platform: add one dict entry here + one API key env var in .env.
No other code changes needed.
"""

from __future__ import annotations

import os

PLATFORM_REGISTRY: dict[str, dict] = {
    "housing_com": {
        "name": "Housing.com",
        "api_type": "rest_api",
        "base_url_env": "HOUSING_COM_API_BASE_URL",
        "api_key_env": "HOUSING_COM_API_KEY",
        "supports_photos": True,
        "property_types": ["Restaurant", "Office", "Shop", "Co-working", "Residence", "Studio Room"],
        "tone": "professional and concise, targeting urban business tenants",
        "active": True,
    },
    "99acres": {
        "name": "99acres.com",
        "api_type": "rest_api",
        "base_url_env": "ACRES99_API_BASE_URL",
        "api_key_env": "ACRES99_API_KEY",
        "supports_photos": True,
        "property_types": ["Restaurant", "Office", "Shop", "Co-working", "Residence", "Parking"],
        "tone": "detailed and feature-rich, emphasizing amenities and sq.ft measurements",
        "active": True,
    },
    "magicbricks": {
        "name": "MagicBricks.com",
        "api_type": "rest_api",
        "base_url_env": "MAGICBRICKS_API_BASE_URL",
        "api_key_env": "MAGICBRICKS_API_KEY",
        "supports_photos": True,
        "property_types": ["Office", "Shop", "Residence", "Co-working"],
        "tone": "aspirational and lifestyle-oriented, highlighting location and brand prestige",
        "active": True,
    },
    "nobroker": {
        "name": "NoBroker.com",
        "api_type": "manual",
        "base_url_env": None,
        "api_key_env": None,
        "supports_photos": False,
        "property_types": ["Office", "Shop", "Residence", "Studio Room", "Co-working"],
        "tone": "straightforward and value-focused, highlighting zero brokerage advantage",
        "active": True,
    },
}


def _disabled_keys() -> set[str]:
    raw = os.getenv("DISABLED_PLATFORMS", "")
    return {k.strip() for k in raw.split(",") if k.strip()}


def get_active_platforms() -> list[str]:
    disabled = _disabled_keys()
    return [k for k, v in PLATFORM_REGISTRY.items() if v["active"] and k not in disabled]


def get_platforms_for_category(category: str) -> list[str]:
    """Return active platform keys that support this property category."""
    disabled = _disabled_keys()
    return [
        k
        for k, v in PLATFORM_REGISTRY.items()
        if v["active"]
        and k not in disabled
        and category in v.get("property_types", [])
    ]
