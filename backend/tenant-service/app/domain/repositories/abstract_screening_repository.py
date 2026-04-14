"""Abstract repository interface for ScreeningResult entities."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Optional
from uuid import UUID

from app.domain.entities.tenant import ScreeningResult


class AbstractScreeningRepository(ABC):
    """Contract that all concrete screening repositories must satisfy."""

    @abstractmethod
    async def create(self, screening: ScreeningResult) -> ScreeningResult:
        """Persist a new screening result and return the saved entity."""
        ...

    @abstractmethod
    async def get_by_id(self, screening_id: UUID) -> Optional[ScreeningResult]:
        """Return a screening result by primary key, or None if not found."""
        ...

    @abstractmethod
    async def get_by_applicant(self, applicant_id: UUID) -> Optional[ScreeningResult]:
        """Return the most recent screening result for an applicant, or None."""
        ...

    @abstractmethod
    async def get_by_external_report_id(
        self, external_report_id: str
    ) -> Optional[ScreeningResult]:
        """Return a screening result by the provider's report ID, or None."""
        ...

    @abstractmethod
    async def update(self, screening: ScreeningResult) -> ScreeningResult:
        """Persist changes to an existing screening result."""
        ...
