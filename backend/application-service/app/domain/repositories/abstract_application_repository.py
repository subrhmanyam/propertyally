"""Abstract repository interface for Application."""

from __future__ import annotations

from abc import ABC, abstractmethod
from uuid import UUID

from app.domain.entities.application import Application, ApplicationStatus


class AbstractApplicationRepository(ABC):
    @abstractmethod
    async def create(self, application: Application) -> Application:
        ...

    @abstractmethod
    async def get_by_id(self, application_id: UUID) -> Application | None:
        ...

    @abstractmethod
    async def update(self, application: Application) -> Application:
        ...

    @abstractmethod
    async def list_by_filters(
        self,
        property_id: UUID | None = None,
        applicant_id: UUID | None = None,
        status: ApplicationStatus | None = None,
        offset: int = 0,
        limit: int = 50,
    ) -> list[Application]:
        ...
