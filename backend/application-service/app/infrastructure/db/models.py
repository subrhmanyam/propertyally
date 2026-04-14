"""SQLAlchemy ORM models for the Application Service (schema: application)."""

from __future__ import annotations

import uuid

from sqlalchemy import (
    ARRAY,
    JSON,
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    SmallInteger,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.infrastructure.db.session import Base

_SCHEMA = "application"


class ApplicationTemplateModel(Base):
    __tablename__ = "templates"
    __table_args__ = {"schema": _SCHEMA}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    property_id = Column(UUID(as_uuid=True), nullable=False)
    name = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=False, nullable=False)
    created_by = Column(UUID(as_uuid=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )

    sections = relationship(
        "FormSectionModel",
        back_populates="template",
        cascade="all, delete-orphan",
        order_by="FormSectionModel.order_index",
    )


class FormSectionModel(Base):
    __tablename__ = "form_sections"
    __table_args__ = {"schema": _SCHEMA}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    template_id = Column(
        UUID(as_uuid=True),
        ForeignKey(f"{_SCHEMA}.templates.id", ondelete="CASCADE"),
        nullable=False,
    )
    title = Column(String(255), nullable=False)
    order_index = Column(SmallInteger, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    template = relationship("ApplicationTemplateModel", back_populates="sections")
    fields = relationship(
        "FormFieldModel",
        back_populates="section",
        cascade="all, delete-orphan",
        order_by="FormFieldModel.order_index",
    )


class FormFieldModel(Base):
    __tablename__ = "form_fields"
    __table_args__ = {"schema": _SCHEMA}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    section_id = Column(
        UUID(as_uuid=True),
        ForeignKey(f"{_SCHEMA}.form_sections.id", ondelete="CASCADE"),
        nullable=False,
    )
    label = Column(String(255), nullable=False)
    field_type = Column(String(30), nullable=False)
    is_required = Column(Boolean, default=False, nullable=False)
    options = Column(ARRAY(Text), default=list)
    order_index = Column(SmallInteger, nullable=False)

    section = relationship("FormSectionModel", back_populates="fields")


class ApplicationModel(Base):
    __tablename__ = "applications"
    __table_args__ = {"schema": _SCHEMA}

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    template_id = Column(
        UUID(as_uuid=True),
        ForeignKey(f"{_SCHEMA}.templates.id"),
        nullable=False,
    )
    property_id = Column(UUID(as_uuid=True), nullable=False)
    unit_id = Column(UUID(as_uuid=True), nullable=True)
    applicant_id = Column(UUID(as_uuid=True), nullable=False)
    applicant_name = Column(String(255), nullable=False)
    applicant_email = Column(String(255), nullable=False)
    responses = Column(JSON, default=dict)
    documents = Column(ARRAY(Text), default=list)
    status = Column(String(30), default="DRAFT", nullable=False)
    reviewer_id = Column(UUID(as_uuid=True), nullable=True)
    reviewer_notes = Column(Text, nullable=True)
    submitted_at = Column(DateTime(timezone=True), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
