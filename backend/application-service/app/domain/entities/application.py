"""Domain entities for the Application Service.

Pure Python dataclasses — no ORM, no framework imports.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Optional
from uuid import UUID


class FieldType(str, Enum):
    TEXT = "TEXT"
    NUMBER = "NUMBER"
    DATE = "DATE"
    DROPDOWN = "DROPDOWN"
    CHECKBOX = "CHECKBOX"
    FILE = "FILE"


class ApplicationStatus(str, Enum):
    DRAFT = "DRAFT"
    SUBMITTED = "SUBMITTED"
    UNDER_REVIEW = "UNDER_REVIEW"
    SCREENING = "SCREENING"
    APPROVED = "APPROVED"
    DENIED = "DENIED"


@dataclass
class FormField:
    id: UUID
    label: str
    field_type: FieldType
    is_required: bool
    options: list[str]
    order: int


@dataclass
class FormSection:
    id: UUID
    title: str
    order: int
    fields: list[FormField]


@dataclass
class ApplicationTemplate:
    id: UUID
    property_id: UUID
    name: str
    sections: list[FormSection]
    is_active: bool
    created_by: UUID
    created_at: datetime
    updated_at: datetime

    def all_required_field_ids(self) -> list[UUID]:
        """Return IDs of all required fields across all sections."""
        return [
            f.id
            for section in self.sections
            for f in section.fields
            if f.is_required
        ]


@dataclass
class Application:
    id: UUID
    template_id: UUID
    property_id: UUID
    unit_id: Optional[UUID]
    applicant_id: UUID
    applicant_name: str
    applicant_email: str
    responses: dict[str, object]
    documents: list[str]
    status: ApplicationStatus
    reviewer_id: Optional[UUID]
    reviewer_notes: Optional[str]
    submitted_at: Optional[datetime]
    reviewed_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    def missing_required_fields(self, required_ids: list[UUID]) -> list[str]:
        """Return string-form UUIDs of required fields that have no response."""
        missing: list[str] = []
        for fid in required_ids:
            key = str(fid)
            val = self.responses.get(key)
            if val is None or val == "" or val == []:
                missing.append(key)
        return missing
