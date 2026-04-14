"""Use case: InitiateScreening — create a PENDING ScreeningResult and call the provider."""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import UUID

from app.domain.entities.tenant import CheckStatus, ScreeningRecommendation, ScreeningResult
from app.domain.repositories.abstract_screening_repository import AbstractScreeningRepository
from app.infrastructure.external.screening_client import request_screening

logger = logging.getLogger(__name__)


@dataclass
class InitiateScreeningInput:
    applicant_id: UUID
    first_name: str
    last_name: str
    email: str
    date_of_birth: str  # ISO format
    ssn_last_four: str


class InitiateScreeningUseCase:
    """Create a pending screening record and dispatch to the external provider."""

    def __init__(self, screening_repo: AbstractScreeningRepository) -> None:
        self._screening_repo = screening_repo

    async def execute(self, data: InitiateScreeningInput) -> ScreeningResult:
        now = datetime.now(tz=timezone.utc)
        screening = ScreeningResult(
            id=uuid.uuid4(),
            applicant_id=data.applicant_id,
            credit_check_status=CheckStatus.PENDING,
            background_check_status=CheckStatus.PENDING,
            eviction_history=False,
            income_verified=False,
            recommendation=ScreeningRecommendation.REVIEW,
            created_at=now,
        )
        saved = await self._screening_repo.create(screening)

        # Fire-and-forget call to the external screening provider stub
        applicant_payload: dict[str, str] = {
            "applicant_id": str(data.applicant_id),
            "first_name": data.first_name,
            "last_name": data.last_name,
            "email": data.email,
            "date_of_birth": data.date_of_birth,
            "ssn_last_four": data.ssn_last_four,
            "report_id": str(saved.id),
        }
        try:
            provider_response = await request_screening(applicant_payload)
            logger.info(
                "screening.initiated screening_id=%s external_id=%s",
                saved.id,
                provider_response.get("external_report_id"),
            )
            # Persist the external report ID returned by the stub
            saved.external_report_id = provider_response.get("external_report_id")
            saved = await self._screening_repo.update(saved)
        except Exception as exc:
            # Non-fatal: record is still PENDING; webhook will deliver real result
            logger.warning(
                "Screening provider call failed for screening_id=%s: %s", saved.id, exc
            )

        return saved
