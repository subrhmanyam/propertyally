"""Use case: mark a work order as complete and upload completion photos.

Transitions the request status to PENDING_APPROVAL so a manager can sign off.
"""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from uuid import UUID

from supabase import Client

from app.config import get_settings
from app.domain.entities.maintenance import RequestStatus, WorkOrder
from app.domain.exceptions import (
    RequestNotFoundError,
    StorageUploadError,
    WorkOrderNotFoundError,
)
from app.domain.repositories.abstract_request_repository import AbstractRequestRepository
from app.domain.repositories.abstract_work_order_repository import AbstractWorkOrderRepository

logger = logging.getLogger(__name__)


class CompleteWorkOrderUseCase:
    """Record completion of work, upload completion photos, set PENDING_APPROVAL."""

    def __init__(
        self,
        request_repo: AbstractRequestRepository,
        work_order_repo: AbstractWorkOrderRepository,
        supabase: Client,
    ) -> None:
        self._request_repo = request_repo
        self._work_order_repo = work_order_repo
        self._supabase = supabase

    async def execute(
        self,
        *,
        request_id: UUID,
        work_notes: str,
        photo_files: list[tuple[str, bytes, str]],  # (filename, content, content_type)
    ) -> WorkOrder:
        settings = get_settings()

        # 1. Verify request and work order exist
        request = await self._request_repo.get_by_id(request_id)
        if request is None:
            raise RequestNotFoundError(str(request_id))

        work_order = await self._work_order_repo.get_by_request_id(request_id)
        if work_order is None:
            raise WorkOrderNotFoundError(f"request_id={request_id}")

        # 2. Upload completion photos
        completion_urls: list[str] = list(work_order.completion_photos)
        for filename, content, content_type in photo_files:
            object_path = (
                f"{request.property_id}/{request.unit_id}/{uuid.uuid4()}_{filename}"
            )
            try:
                self._supabase.storage.from_(settings.storage_bucket_completion).upload(
                    path=object_path,
                    file=content,
                    file_options={"content-type": content_type},
                )
                public_url: str = self._supabase.storage.from_(
                    settings.storage_bucket_completion
                ).get_public_url(object_path)
                completion_urls.append(public_url)
                logger.debug("Uploaded completion photo to %s", public_url)
            except Exception as exc:
                logger.error("Failed to upload completion photo '%s': %s", filename, exc)
                raise StorageUploadError(str(exc)) from exc

        # 3. Mark work order completed
        updated = await self._work_order_repo.update(
            work_order.id,
            work_notes=work_notes,
            completion_photos=completion_urls,
            completed_at=datetime.now(tz=timezone.utc),
        )

        # 4. Transition request → PENDING_APPROVAL
        await self._request_repo.update_status(request_id, RequestStatus.PENDING_APPROVAL)

        logger.info(
            "Work order id=%s completed; request id=%s moved to PENDING_APPROVAL",
            work_order.id,
            request_id,
        )
        return updated
