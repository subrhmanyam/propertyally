"""Abstract repository interface for TenantDocument entities."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Optional
from uuid import UUID

from app.domain.entities.tenant import TenantDocument


class AbstractDocumentRepository(ABC):
    """Contract that all concrete document repositories must satisfy."""

    @abstractmethod
    async def create(self, document: TenantDocument) -> TenantDocument:
        """Persist a new document record and return the saved entity."""
        ...

    @abstractmethod
    async def get_by_id(self, document_id: UUID) -> Optional[TenantDocument]:
        """Return a document by primary key, or None if not found."""
        ...

    @abstractmethod
    async def list_by_tenant(self, tenant_id: UUID) -> list[TenantDocument]:
        """Return all documents for a tenant, ordered by upload date descending."""
        ...

    @abstractmethod
    async def delete(self, document_id: UUID) -> None:
        """Remove a document record from the database."""
        ...
