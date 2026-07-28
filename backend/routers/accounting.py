"""Accounting router — transactions, rent invoices, and KPIs."""

from __future__ import annotations

import json
from datetime import date
from typing import Any

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from auth_utils import require_any_org_admin, require_org_admin_for_unit
from db import get_supabase

router = APIRouter()


def _require_admin(sb, user_id: str, unit_id: str | None) -> None:
    if unit_id:
        require_org_admin_for_unit(sb, user_id, unit_id)
    else:
        require_any_org_admin(sb, user_id)


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------


class TransactionIn(BaseModel):
    type: str  # income | expense
    category: str
    amount: float
    currency: str = "INR"
    date: str
    description: str
    status: str = "paid"
    leasing_unit_id: str | None = None
    tenant_id: str | None = None
    lease_id: str | None = None
    reference_no: str | None = None
    notes: str | None = None


class StatusPatch(BaseModel):
    status: str  # paid | pending | overdue


# ---------------------------------------------------------------------------
# Transactions
# ---------------------------------------------------------------------------


@router.get("/transactions")
async def list_transactions(
    type: str | None = Query(None),
    status: str | None = Query(None),
    leasing_unit_id: str | None = Query(None),
    from_date: str | None = Query(None),
    to_date: str | None = Query(None),
) -> list[dict[str, Any]]:
    sb = get_supabase()
    q = sb.table("transactions").select("*")
    if type:
        q = q.eq("type", type)
    if status:
        q = q.eq("status", status)
    if leasing_unit_id:
        q = q.eq("leasing_unit_id", leasing_unit_id)
    if from_date:
        q = q.gte("date", from_date)
    if to_date:
        q = q.lte("date", to_date)
    return q.order("date", desc=True).execute().data or []


@router.get("/transactions/{transaction_id}")
async def get_transaction(transaction_id: str) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("transactions").select("*").eq("id", transaction_id).limit(1).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return res.data[0]


@router.post("/transactions", status_code=201)
async def create_transaction(user_id: str, payload: TransactionIn) -> dict[str, Any]:
    sb = get_supabase()
    _require_admin(sb, user_id, payload.leasing_unit_id)
    res = sb.table("transactions").insert(payload.model_dump()).execute()
    return res.data[0]


@router.put("/transactions/{transaction_id}")
async def update_transaction(transaction_id: str, user_id: str, payload: TransactionIn) -> dict[str, Any]:
    sb = get_supabase()
    current = sb.table("transactions").select("leasing_unit_id").eq("id", transaction_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
    _require_admin(sb, user_id, payload.leasing_unit_id or current.data[0].get("leasing_unit_id"))
    res = sb.table("transactions").update(payload.model_dump()).eq("id", transaction_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return res.data[0]


@router.patch("/transactions/{transaction_id}/status")
async def patch_transaction_status(transaction_id: str, user_id: str, body: StatusPatch) -> dict[str, Any]:
    allowed = {"paid", "pending", "overdue"}
    if body.status not in allowed:
        raise HTTPException(status_code=400, detail=f"status must be one of {allowed}")
    sb = get_supabase()
    current = sb.table("transactions").select("leasing_unit_id").eq("id", transaction_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
    _require_admin(sb, user_id, current.data[0].get("leasing_unit_id"))
    res = sb.table("transactions").update({"status": body.status}).eq("id", transaction_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return res.data[0]


@router.delete("/transactions/{transaction_id}", status_code=204)
async def delete_transaction(transaction_id: str, user_id: str) -> None:
    sb = get_supabase()
    current = sb.table("transactions").select("leasing_unit_id").eq("id", transaction_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
    _require_admin(sb, user_id, current.data[0].get("leasing_unit_id"))
    sb.table("transactions").delete().eq("id", transaction_id).execute()


# ---------------------------------------------------------------------------
# Invoice generation
# ---------------------------------------------------------------------------


def _fiscal_year(d: date) -> str:
    """Return Indian fiscal year string like '2025-26'."""
    y = d.year if d.month >= 4 else d.year - 1
    return f"{y}-{str(y + 1)[2:]}"


@router.post("/invoices/generate", status_code=201)
async def generate_monthly_invoices(user_id: str) -> dict[str, Any]:
    """Generate pending rent invoices for all active leases for the current month.

    Idempotent — skips any lease that already has a Rent transaction for this
    calendar month (detected via the period field in notes JSON).
    """
    sb = get_supabase()
    require_any_org_admin(sb, user_id)
    today = date.today()
    period_key = today.strftime("%Y-%m")
    fiscal_yr = _fiscal_year(today)
    month_label = today.strftime("%B %Y")

    # Fetch active leases whose date range covers today, with tenant + unit names
    leases_resp = (
        sb.table("leases")
        .select("*, tenants(first_name, last_name), leasing_units(name)")
        .eq("status", "active")
        .lte("start_date", str(today))
        .gte("end_date", str(today))
        .execute()
    )
    leases: list[dict] = leases_resp.data or []

    # Fetch all Rent transactions for this period to check duplicates in one query
    existing_resp = (
        sb.table("transactions")
        .select("lease_id, notes")
        .eq("type", "income")
        .eq("category", "Rent")
        .execute()
    )
    already_generated: set[str] = set()
    for row in existing_resp.data or []:
        try:
            n = json.loads(row.get("notes") or "{}")
            if n.get("period") == period_key and row.get("lease_id"):
                already_generated.add(row["lease_id"])
        except (json.JSONDecodeError, TypeError):
            pass

    # Count existing Rent invoices to build sequential invoice numbers
    base_seq = len([r for r in existing_resp.data or [] if r.get("lease_id") not in already_generated]) + 1

    created: list[dict] = []
    skipped: list[str] = []

    for i, lease in enumerate(leases):
        lease_id = lease["id"]
        if lease_id in already_generated:
            skipped.append(lease_id)
            continue

        tenant = lease.get("tenants") or {}
        unit = lease.get("leasing_units") or {}
        tenant_name = f"{tenant.get('first_name', '')} {tenant.get('last_name', '')}".strip() or "Tenant"
        unit_name = unit.get("name", "")

        base_rent = float(lease.get("monthly_rent", 0))
        cgst = round(base_rent * 0.09, 2)
        sgst = round(base_rent * 0.09, 2)
        total_with_gst = round(base_rent + cgst + sgst, 2)

        invoice_no = f"BG/{fiscal_yr}/{base_seq + len(created):04d}"
        due_date = date(today.year, today.month, 1)
        # 5-day grace period — mark overdue only after 5th
        is_overdue = today.day > 5

        notes_payload = json.dumps({
            "period": period_key,
            "invoice_no": invoice_no,
            "base_rent": base_rent,
            "cgst_9pct": cgst,
            "sgst_9pct": sgst,
            "total_with_gst": total_with_gst,
            "fiscal_year": fiscal_yr,
        })

        tx = {
            "type": "income",
            "category": "Rent",
            "amount": base_rent,
            "currency": "INR",
            "date": str(due_date),
            "description": f"Rent Invoice — {tenant_name} — {unit_name} — {month_label}",
            "status": "overdue" if is_overdue else "pending",
            "leasing_unit_id": lease.get("leasing_unit_id"),
            "tenant_id": lease.get("tenant_id"),
            "lease_id": lease_id,
            "reference_no": invoice_no,
            "notes": notes_payload,
        }

        result = sb.table("transactions").insert(tx).execute()
        if result.data:
            created.append(result.data[0])

    return {
        "period": period_key,
        "fiscal_year": fiscal_yr,
        "active_leases": len(leases),
        "created": len(created),
        "skipped_already_exists": len(skipped),
        "invoices": created,
    }


# ---------------------------------------------------------------------------
# Summary / KPIs
# ---------------------------------------------------------------------------


@router.get("/summary")
async def accounting_summary(
    from_date: str | None = Query(None),
    to_date: str | None = Query(None),
) -> dict[str, Any]:
    sb = get_supabase()
    q = sb.table("transactions").select("type,amount,status")
    if from_date:
        q = q.gte("date", from_date)
    if to_date:
        q = q.lte("date", to_date)
    rows = q.execute().data or []

    total_income = sum(r["amount"] for r in rows if r["type"] == "income" and r["status"] == "paid")
    total_expenses = sum(r["amount"] for r in rows if r["type"] == "expense" and r["status"] == "paid")
    outstanding = sum(r["amount"] for r in rows if r["type"] == "income" and r["status"] == "pending")
    overdue = sum(r["amount"] for r in rows if r["type"] == "income" and r["status"] == "overdue")

    return {
        "total_income": total_income,
        "total_expenses": total_expenses,
        "net_income": total_income - total_expenses,
        "outstanding_rent": outstanding,
        "overdue_rent": overdue,
    }
