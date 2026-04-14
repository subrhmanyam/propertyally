"""Domain entities for the Reports Service."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from enum import Enum
from typing import Any, Optional
from uuid import UUID


class ReportType(str, Enum):
    FINANCIAL_SUMMARY = "FINANCIAL_SUMMARY"
    RENT_ROLL = "RENT_ROLL"
    OCCUPANCY = "OCCUPANCY"
    MAINTENANCE_SUMMARY = "MAINTENANCE_SUMMARY"
    TENANT_LEDGER = "TENANT_LEDGER"
    EXPENSE_BREAKDOWN = "EXPENSE_BREAKDOWN"
    INCOME_STATEMENT = "INCOME_STATEMENT"


class ReportStatus(str, Enum):
    QUEUED = "QUEUED"
    GENERATING = "GENERATING"
    READY = "READY"
    FAILED = "FAILED"


class ReportFormat(str, Enum):
    PDF = "PDF"
    CSV = "CSV"


@dataclass
class ReportRequest:
    id: UUID
    report_type: ReportType
    requested_by: UUID
    parameters: dict[str, Any]
    format: ReportFormat
    status: ReportStatus
    file_url: Optional[str]
    error_message: Optional[str]
    generated_at: Optional[datetime]
    created_at: datetime


@dataclass
class ReportSchedule:
    id: UUID
    report_type: ReportType
    owner_id: UUID
    parameters: dict[str, Any]
    cron_expr: str
    last_run_at: Optional[datetime]
    next_run_at: Optional[datetime]
    is_active: bool
    created_at: datetime


@dataclass
class FinancialSummary:
    property_id: UUID
    from_date: str
    to_date: str
    total_revenue: float
    total_expenses: float
    net_income: float
    outstanding_rent: float
    monthly_breakdown: list[dict[str, Any]] = field(default_factory=list)
