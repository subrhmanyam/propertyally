"""Domain entity for an authentication token pair. Pure dataclass."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class TokenPair:
    access_token: str
    refresh_token: str
    token_type: str = field(default="bearer")
