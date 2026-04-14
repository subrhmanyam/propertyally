"""Accounting router — transactions and rent schedules."""

from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from db import get_supabase

router = APIRouter()


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
    res = sb.table("transactions").select("*").eq("id", transaction_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return res.data


@router.post("/transactions", status_code=201)
async def create_transaction(payload: TransactionIn) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("transactions").insert(payload.model_dump()).execute()
    return res.data[0]


@router.put("/transactions/{transaction_id}")
async def update_transaction(transaction_id: str, payload: TransactionIn) -> dict[str, Any]:
    sb = get_supabase()
    res = sb.table("transactions").update(payload.model_dump()).eq("id", transaction_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return res.data[0]


@router.delete("/transactions/{transaction_id}", status_code=204)
async def delete_transaction(transaction_id: str) -> None:
    sb = get_supabase()
    sb.table("transactions").delete().eq("id", transaction_id).execute()


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
