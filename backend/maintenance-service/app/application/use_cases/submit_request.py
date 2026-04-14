"""Use case: tenant or manager submits a new maintenance request.

Responsibilities:
  1. Upload any attached photos to Supabase Storage.
  2. Persist the request with OPEN status.
  3. Return the created domain entity.
"""

from __future__ import annotations

import logging
import uuid
from typing import Optional
from uuid import UUID

from supabase import Client

from app.config import get_settings
from app.domain.entities.maintenance import (
    MaintenanceCategory,
    MaintenanceRequest,
    Priority,
)
from app.domain.exceptions import StorageUploadError
from app.domain.repositories.abstract_request_repository import AbstractRequestRepository

logger = logging.getLogger(__name__)


class SubmitRequestUseCase:
    """Create a new maintenance request, uploading photos if provided."""

    def __init__(
        self,
        request_repo: AbstractRequestRepository,
        supabase: Client,
    ) -> None:
        self._request_repo = request_repo
        self._supabase = supabase

    async def execute(
        self,
        *,
        unit_id: UUID,
        property_id: UUID,
        tenant_id: Optional[UUID],
        title: str,
        description: str,
        category: MaintenanceCategory,
        priority: Priority,
        photo_files: list[tuple[str, bytes, str]],  # (filename, content, content_type)
    ) -> MaintenanceRequest:
        """
        Parameters
        ----------
        photo_files:
            A list of ``(filename, bytes, content_type)`` tuples for each photo
            to upload.  Pass an empty list when no photos are attached.
        """
        settings = get_settings()
        photo_urls: list[str] = []

        for filename, content, content_type in photo_files:
            object_path = f"{property_id}/{unit_id}/{uuid.uuid4()}_{filename}"
            try:
                self._supabase.storage.from_(settings.storage_bucket_photos).upload(
                    path=object_path,
                    file=content,
                    file_options={"content-type": content_type},
                )
                public_url: str = self._supabase.storage.from_(
                    settings.storage_bucket_photos
                ).get_public_url(object_path)
                photo_urls.append(public_url)
                logger.debug("Uploaded photo to %s", public_url)
            except Exception as exc:
                logger.error("Failed to upload photo '%s': %s", filename, exc)
                raise StorageUploadError(str(exc)) from exc

        request = await self._request_repo.create(
            unit_id=unit_id,
            property_id=property_id,
            tenant_id=tenant_id,
            title=title,
            description=description,
            category=category,
            priority=priority,
            photos=photo_urls,
        )

        logger.info(
            "Maintenance request submitted id=%s property=%s priority=%s",
            request.id,
            property_id,
            priority.value,
        )
        return request
