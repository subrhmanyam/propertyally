"""RefreshTokenUseCase — exchange a refresh token for a new token pair."""

from __future__ import annotations

import logging
from dataclasses import dataclass

from supabase import Client

from app.domain.entities.token import TokenPair
from app.domain.exceptions import InvalidTokenError

logger = logging.getLogger(__name__)


@dataclass
class RefreshTokenInput:
    refresh_token: str


@dataclass
class RefreshTokenOutput:
    tokens: TokenPair


class RefreshTokenUseCase:
    """
    Delegates refresh to Supabase Auth, which validates the opaque token and
    issues a fresh JWT pair.  We do not re-validate the refresh token in our
    own DB here because Supabase is the authoritative store for its own tokens.
    """

    def __init__(self, supabase: Client) -> None:
        self._supabase = supabase

    async def execute(self, inp: RefreshTokenInput) -> RefreshTokenOutput:
        try:
            response = self._supabase.auth.refresh_session(inp.refresh_token)
        except Exception as exc:
            logger.warning("Token refresh failed: %s", exc)
            raise InvalidTokenError("Refresh token is invalid or expired.") from exc

        if response.session is None:
            raise InvalidTokenError("Refresh token is invalid or expired.")

        session = response.session
        logger.debug("Token refreshed successfully")
        return RefreshTokenOutput(
            tokens=TokenPair(
                access_token=session.access_token,
                refresh_token=session.refresh_token,
            )
        )
