"""Abstract repository interface for ApplicationTemplate."""

from __future__ import annotations

from abc import ABC, abstractmethod
from uuid import UUID

from app.domain.entities.application import ApplicationTemplate


class AbstractTemplateRepository(ABC):
    @abstractmethod
    async def create(self, template: ApplicationTemplate) -> ApplicationTemplate:
        ...

    @abstractmethod
    async def get_by_id(self, template_id: UUID) -> ApplicationTemplate | None:
        ...

    @abstractmethod
    async def list_by_property(self, property_id: UUID) -> list[ApplicationTemplate]:
        ...

    @abstractmethod
    async def update(self, template: ApplicationTemplate) -> ApplicationTemplate:
        ...

    @abstractmethod
    async def delete(self, template_id: UUID) -> None:
        ...
