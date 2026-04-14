"""Use case: Create an application template."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from uuid import UUID, uuid4

from app.domain.entities.application import ApplicationTemplate, FormField, FormSection
from app.domain.repositories.abstract_template_repository import AbstractTemplateRepository

logger = logging.getLogger(__name__)


@dataclass
class CreateSectionInput:
    title: str
    order: int
    fields: list[CreateFieldInput]


@dataclass
class CreateFieldInput:
    label: str
    field_type: str
    is_required: bool
    options: list[str]
    order: int


@dataclass
class CreateTemplateInput:
    property_id: UUID
    name: str
    sections: list[CreateSectionInput]
    created_by: UUID


class CreateTemplateUseCase:
    def __init__(self, template_repo: AbstractTemplateRepository) -> None:
        self._repo = template_repo

    async def execute(self, data: CreateTemplateInput) -> ApplicationTemplate:
        from app.domain.entities.application import FieldType

        now = datetime.now(timezone.utc)
        sections: list[FormSection] = []
        for sec_data in data.sections:
            fields: list[FormField] = []
            for f in sec_data.fields:
                fields.append(
                    FormField(
                        id=uuid4(),
                        label=f.label,
                        field_type=FieldType(f.field_type),
                        is_required=f.is_required,
                        options=f.options,
                        order=f.order,
                    )
                )
            sections.append(
                FormSection(
                    id=uuid4(),
                    title=sec_data.title,
                    order=sec_data.order,
                    fields=fields,
                )
            )

        template = ApplicationTemplate(
            id=uuid4(),
            property_id=data.property_id,
            name=data.name,
            sections=sections,
            is_active=False,
            created_by=data.created_by,
            created_at=now,
            updated_at=now,
        )

        created = await self._repo.create(template)
        logger.info("Template created: id=%s property=%s", created.id, created.property_id)
        return created
