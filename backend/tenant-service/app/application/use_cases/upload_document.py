"""Use case: UploadDocument — upload file to Supabase Storage and persist record."""

from __future__ import annotations

import logging
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from app.config import get_settings
from app.domain.entities.tenant import DocumentType, TenantDocument
from app.domain.exceptions import StorageUploadError, TenantNotFoundError
from app.domain.repositories.abstract_document_repository import AbstractDocumentRepository
from app.domain.repositories.abstract_tenant_repository import AbstractTenantRepository

logger = logging.getLogger(__name__)


@dataclass
class UploadDocumentInput:
    tenant_id: UUID
    file_bytes: bytes
    file_name: str
    content_type: str
    document_type: DocumentType = DocumentType.OTHER


class UploadDocumentUseCase:
    """Upload a document to Supabase Storage and store the resulting URL in the DB."""

    def __init__(
        self,
        tenant_repo: AbstractTenantRepository,
        document_repo: AbstractDocumentRepository,
    ) -> None:
        self._tenant_repo = tenant_repo
        self._document_repo = document_repo

    async def execute(self, data: UploadDocumentInput) -> TenantDocument:
        tenant = await self._tenant_repo.get_by_id(data.tenant_id)
        if tenant is None:
            raise TenantNotFoundError(str(data.tenant_id))

        settings = get_settings()
        storage_path = f"{data.tenant_id}/{uuid.uuid4()}_{data.file_name}"
        file_url = await self._upload_to_supabase(
            settings.supabase_url,
            settings.supabase_service_key,
            settings.document_bucket,
            storage_path,
            data.file_bytes,
            data.content_type,
        )

        now = datetime.now(tz=timezone.utc)
        document = TenantDocument(
            id=uuid.uuid4(),
            tenant_id=data.tenant_id,
            file_url=file_url,
            uploaded_at=now,
            document_type=data.document_type,
            file_name=data.file_name,
        )
        saved = await self._document_repo.create(document)
        logger.info(
            "document.uploaded document_id=%s tenant_id=%s path=%s",
            saved.id,
            data.tenant_id,
            storage_path,
        )
        return saved

    @staticmethod
    async def _upload_to_supabase(
        supabase_url: str,
        service_key: str,
        bucket: str,
        path: str,
        file_bytes: bytes,
        content_type: str,
    ) -> str:
        """Upload bytes to Supabase Storage and return the public URL."""
        import httpx

        upload_url = f"{supabase_url}/storage/v1/object/{bucket}/{path}"
        headers = {
            "Authorization": f"Bearer {service_key}",
            "Content-Type": content_type,
        }
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(upload_url, content=file_bytes, headers=headers)
                response.raise_for_status()
        except httpx.HTTPStatusError as exc:
            raise StorageUploadError(f"HTTP {exc.response.status_code}: {exc.response.text}") from exc
        except httpx.RequestError as exc:
            raise StorageUploadError(str(exc)) from exc

        public_url = f"{supabase_url}/storage/v1/object/public/{bucket}/{path}"
        return public_url
