"""Use case: UpdateScreeningResult — process webhook from screening provider."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional

from app.domain.entities.tenant import CheckStatus, ScreeningRecommendation, ScreeningResult
from app.domain.exceptions import ScreeningNotFoundError
from app.domain.repositories.abstract_screening_repository import AbstractScreeningRepository

logger = logging.getLogger(__name__)


@dataclass
class UpdateScreeningInput:
    external_report_id: str
    credit_score: Optional[int]
    credit_check_status: CheckStatus
    background_check_status: CheckStatus
    eviction_history: bool
    income_verified: bool
    recommendation: ScreeningRecommendation
    report_url: Optional[str] = None


class UpdateScreeningResultUseCase:
    """Apply incoming webhook data to an existing ScreeningResult."""

    def __init__(self, screening_repo: AbstractScreeningRepository) -> None:
        self._screening_repo = screening_repo

    async def execute(self, data: UpdateScreeningInput) -> ScreeningResult:
        screening = await self._screening_repo.get_by_external_report_id(data.external_report_id)
        if screening is None:
            raise ScreeningNotFoundError(data.external_report_id)

        now = datetime.now(tz=timezone.utc)
        screening.credit_score = data.credit_score
        screening.credit_check_status = data.credit_check_status
        screening.background_check_status = data.background_check_status
        screening.eviction_history = data.eviction_history
        screening.income_verified = data.income_verified
        screening.recommendation = data.recommendation
        screening.report_url = data.report_url
        screening.completed_at = now

        updated = await self._screening_repo.update(screening)
        logger.info(
            "screening.completed screening_id=%s recommendation=%s",
            updated.id,
            updated.recommendation,
        )
        return updated
