"""SQLAlchemy ORM models for the reports schema."""

from __future__ import annotations

import uuid

from sqlalchemy import JSON, Boolean, Column, DateTime, String, Text, func
from sqlalchemy.dialects.postgresql import UUID as PGUUID
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass


class ReportRequestModel(Base):
    __tablename__ = "report_requests"
    __table_args__ = {"schema": "reports"}

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    report_type = Column(String(50), nullable=False)
    requested_by = Column(PGUUID(as_uuid=True), nullable=False)
    parameters = Column(JSON, nullable=False, default=dict)
    format = Column(String(10), nullable=False, default="PDF")
    status = Column(String(20), nullable=False, default="QUEUED")
    file_url = Column(Text, nullable=True)
    error_message = Column(Text, nullable=True)
    generated_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())


class ReportScheduleModel(Base):
    __tablename__ = "schedules"
    __table_args__ = {"schema": "reports"}

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    report_type = Column(String(50), nullable=False)
    owner_id = Column(PGUUID(as_uuid=True), nullable=False)
    parameters = Column(JSON, nullable=False, default=dict)
    cron_expr = Column(String(50), nullable=False)
    last_run_at = Column(DateTime(timezone=True), nullable=True)
    next_run_at = Column(DateTime(timezone=True), nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), nullable=False, server_default=func.now())
