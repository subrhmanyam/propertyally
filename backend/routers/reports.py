"""Reports router — real-time analytics and report generation."""

from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timezone
from typing import Any

from fastapi import APIRouter, Query
from pydantic import BaseModel

from db import get_supabase

router = APIRouter()


# ── helpers ───────────────────────────────────────────────────────────────────

def _month_key(d: str) -> str:
    """'2024-03-15' → '2024-03'"""
    return d[:7] if d else ""


def _month_label(key: str) -> str:
    """'2024-03' → 'Mar 24'"""
    try:
        dt = datetime.strptime(key, "%Y-%m")
        return dt.strftime("%b %y")
    except ValueError:
        return key


def _last_n_months(n: int) -> list[str]:
    """Return list of 'YYYY-MM' keys for last n months including current."""
    today = date.today()
    months = []
    year, month = today.year, today.month
    for _ in range(n):
        months.append(f"{year:04d}-{month:02d}")
        month -= 1
        if month == 0:
            month = 12
            year -= 1
    return list(reversed(months))


# ── Saved reports CRUD (existing) ─────────────────────────────────────────────

class ReportIn(BaseModel):
    name: str
    type: str
    filters: dict[str, Any] = {}
    generated_by: str | None = None


@router.get("/")
async def list_reports() -> list[dict[str, Any]]:
    sb = get_supabase()
    return sb.table("reports").select("*").order("created_at", desc=True).execute().data or []


@router.get("/{report_id}")
async def get_report(report_id: str) -> dict[str, Any]:
    from fastapi import HTTPException
    sb = get_supabase()
    res = sb.table("reports").select("*").eq("id", report_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Report not found")
    return res.data


@router.post("/", status_code=201)
async def create_report(payload: ReportIn) -> dict[str, Any]:
    sb = get_supabase()
    data = payload.model_dump()
    data["generated_at"] = datetime.now(tz=timezone.utc).isoformat()
    res = sb.table("reports").insert(data).execute()
    return res.data[0]


@router.delete("/{report_id}", status_code=204)
async def delete_report(report_id: str) -> None:
    sb = get_supabase()
    sb.table("reports").delete().eq("id", report_id).execute()


# ── 1. Occupancy Report ───────────────────────────────────────────────────────

@router.get("/data/occupancy")
async def occupancy_report() -> dict[str, Any]:
    """Occupancy breakdown by status, category, and floor."""
    sb = get_supabase()
    units = sb.table("leasing_units").select("id,name,category,floor,status").execute().data or []

    total = len(units)
    by_status: dict[str, int] = defaultdict(int)
    by_category: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))
    by_floor: dict[str, dict[str, int]] = defaultdict(lambda: defaultdict(int))

    for u in units:
        s = u.get("status", "vacant")
        cat = u.get("category", "Other")
        floor = u.get("floor", "Unknown")
        by_status[s] += 1
        by_category[cat][s] += 1
        by_floor[floor][s] += 1

    occupied_count = by_status.get("occupied", 0)
    occupancy_rate = round(occupied_count / total * 100, 1) if total else 0

    return {
        "total_units": total,
        "occupied": by_status.get("occupied", 0),
        "vacant": by_status.get("vacant", 0),
        "in_house": by_status.get("in_house", 0),
        "owner_occupied": by_status.get("owner_occupied", 0),
        "occupancy_rate": occupancy_rate,
        "by_category": [
            {
                "category": cat,
                "total": sum(counts.values()),
                "occupied": counts.get("occupied", 0),
                "vacant": counts.get("vacant", 0),
                "occupancy_rate": round(counts.get("occupied", 0) / max(sum(counts.values()), 1) * 100, 1),
            }
            for cat, counts in sorted(by_category.items())
        ],
        "by_floor": [
            {
                "floor": floor,
                "total": sum(counts.values()),
                "occupied": counts.get("occupied", 0),
                "vacant": counts.get("vacant", 0),
            }
            for floor, counts in sorted(by_floor.items())
        ],
    }


# ── 2. Cash Flow Report ───────────────────────────────────────────────────────

@router.get("/data/cash-flow")
async def cash_flow_report(
    months: int = Query(12, ge=1, le=36),
) -> dict[str, Any]:
    """Monthly income vs expenses for last N months."""
    sb = get_supabase()
    month_keys = _last_n_months(months)
    start_date = month_keys[0] + "-01"

    txns = (
        sb.table("transactions")
        .select("type,amount,date,category,status")
        .gte("date", start_date)
        .execute()
        .data or []
    )

    income_by_month: dict[str, float] = defaultdict(float)
    expense_by_month: dict[str, float] = defaultdict(float)
    total_income = 0.0
    total_expenses = 0.0

    for t in txns:
        mk = _month_key(t.get("date", ""))
        if mk not in month_keys:
            continue
        amt = float(t.get("amount", 0))
        if t.get("type") == "income":
            income_by_month[mk] += amt
            total_income += amt
        elif t.get("type") == "expense":
            expense_by_month[mk] += amt
            total_expenses += amt

    monthly = [
        {
            "month": mk,
            "label": _month_label(mk),
            "income": round(income_by_month[mk], 2),
            "expenses": round(expense_by_month[mk], 2),
            "net": round(income_by_month[mk] - expense_by_month[mk], 2),
        }
        for mk in month_keys
    ]

    return {
        "total_income": round(total_income, 2),
        "total_expenses": round(total_expenses, 2),
        "net": round(total_income - total_expenses, 2),
        "months": monthly,
    }


# ── 3. Rent Collection Report ─────────────────────────────────────────────────

@router.get("/data/rent-collection")
async def rent_collection_report(
    year: int = Query(None),
    month: int = Query(None),
) -> dict[str, Any]:
    """Rent collected vs pending vs overdue — optionally filtered by period."""
    sb = get_supabase()

    today = date.today()
    y = year or today.year
    m = month or today.month

    # Fetch rent income transactions
    q = (
        sb.table("transactions")
        .select("id,amount,status,date,description,leasing_unit_id,tenant_id")
        .eq("type", "income")
        .eq("category", "Rent")
    )
    if year or month:
        period = f"{y:04d}-{m:02d}"
        q = q.gte("date", f"{period}-01").lte("date", f"{period}-31")

    txns = q.execute().data or []

    collected = sum(float(t["amount"]) for t in txns if t.get("status") == "paid")
    pending = sum(float(t["amount"]) for t in txns if t.get("status") == "pending")
    overdue = sum(float(t["amount"]) for t in txns if t.get("status") == "overdue")
    total = collected + pending + overdue
    collection_rate = round(collected / total * 100, 1) if total else 0

    # Fetch unit names for display
    unit_ids = list({t["leasing_unit_id"] for t in txns if t.get("leasing_unit_id")})
    unit_map: dict[str, str] = {}
    if unit_ids:
        units = sb.table("leasing_units").select("id,name").in_("id", unit_ids).execute().data or []
        unit_map = {u["id"]: u["name"] for u in units}

    # Per-unit breakdown
    by_unit: dict[str, dict[str, float]] = defaultdict(lambda: {"collected": 0, "pending": 0, "overdue": 0})
    for t in txns:
        uid = t.get("leasing_unit_id", "unknown")
        status = t.get("status", "pending")
        amt = float(t.get("amount", 0))
        if status in ("paid",):
            by_unit[uid]["collected"] += amt
        elif status == "pending":
            by_unit[uid]["pending"] += amt
        elif status == "overdue":
            by_unit[uid]["overdue"] += amt

    return {
        "period": f"{y:04d}-{m:02d}" if (year or month) else "all",
        "collected": round(collected, 2),
        "pending": round(pending, 2),
        "overdue": round(overdue, 2),
        "total": round(total, 2),
        "collection_rate": collection_rate,
        "by_unit": [
            {
                "unit_id": uid,
                "unit_name": unit_map.get(uid, uid),
                "collected": round(vals["collected"], 2),
                "pending": round(vals["pending"], 2),
                "overdue": round(vals["overdue"], 2),
            }
            for uid, vals in by_unit.items()
        ],
    }


# ── 4. Maintenance Costs Report ───────────────────────────────────────────────

@router.get("/data/maintenance-costs")
async def maintenance_costs_report(
    months: int = Query(12, ge=1, le=36),
) -> dict[str, Any]:
    """Maintenance spend by category, status, and month."""
    sb = get_supabase()
    month_keys = _last_n_months(months)
    start_date = month_keys[0] + "-01"

    reqs = (
        sb.table("maintenance_requests")
        .select("id,category,status,actual_cost,estimated_cost,created_at,leasing_unit_id")
        .gte("created_at", start_date)
        .execute()
        .data or []
    )

    total_actual = 0.0
    total_estimated = 0.0
    by_category: dict[str, dict[str, Any]] = defaultdict(lambda: {"count": 0, "actual": 0.0, "estimated": 0.0})
    by_month: dict[str, float] = defaultdict(float)
    by_status: dict[str, int] = defaultdict(int)

    for r in reqs:
        cat = r.get("category") or "General"
        actual = float(r.get("actual_cost") or 0)
        estimated = float(r.get("estimated_cost") or 0)
        mk = _month_key((r.get("created_at") or "")[:10])
        status = r.get("status", "open")

        total_actual += actual
        total_estimated += estimated
        by_category[cat]["count"] += 1
        by_category[cat]["actual"] += actual
        by_category[cat]["estimated"] += estimated
        if mk in month_keys:
            by_month[mk] += actual
        by_status[status] += 1

    # Fetch unit names
    unit_ids = list({r["leasing_unit_id"] for r in reqs if r.get("leasing_unit_id")})
    unit_map: dict[str, str] = {}
    if unit_ids:
        units = sb.table("leasing_units").select("id,name").in_("id", unit_ids).execute().data or []
        unit_map = {u["id"]: u["name"] for u in units}

    by_unit: dict[str, dict[str, Any]] = defaultdict(lambda: {"count": 0, "actual": 0.0})
    for r in reqs:
        uid = r.get("leasing_unit_id", "unknown")
        by_unit[uid]["count"] += 1
        by_unit[uid]["actual"] += float(r.get("actual_cost") or 0)

    return {
        "total_requests": len(reqs),
        "total_actual_cost": round(total_actual, 2),
        "total_estimated_cost": round(total_estimated, 2),
        "by_status": dict(by_status),
        "by_category": [
            {
                "category": cat,
                "count": vals["count"],
                "actual_cost": round(vals["actual"], 2),
                "estimated_cost": round(vals["estimated"], 2),
            }
            for cat, vals in sorted(by_category.items(), key=lambda x: -x[1]["actual"])
        ],
        "by_month": [
            {
                "month": mk,
                "label": _month_label(mk),
                "cost": round(by_month[mk], 2),
            }
            for mk in month_keys
        ],
        "by_unit": [
            {
                "unit_id": uid,
                "unit_name": unit_map.get(uid, uid),
                "count": vals["count"],
                "actual_cost": round(vals["actual"], 2),
            }
            for uid, vals in sorted(by_unit.items(), key=lambda x: -x[1]["actual"])
        ],
    }


# ── 5. Profit & Loss Report ───────────────────────────────────────────────────

@router.get("/data/profit-loss")
async def profit_loss_report(
    year: int = Query(None),
    months: int = Query(12, ge=1, le=36),
) -> dict[str, Any]:
    """Income vs expenses per leasing unit + monthly P&L breakdown."""
    sb = get_supabase()

    if year:
        start_date = f"{year:04d}-01-01"
        end_date = f"{year:04d}-12-31"
        month_keys = [f"{year:04d}-{m:02d}" for m in range(1, 13)]
    else:
        month_keys = _last_n_months(months)
        start_date = month_keys[0] + "-01"
        end_date = date.today().isoformat()

    txns = (
        sb.table("transactions")
        .select("type,amount,date,leasing_unit_id,category")
        .gte("date", start_date)
        .lte("date", end_date)
        .execute()
        .data or []
    )

    # Overall monthly P&L
    income_by_month: dict[str, float] = defaultdict(float)
    expense_by_month: dict[str, float] = defaultdict(float)
    total_income = 0.0
    total_expenses = 0.0

    # Per-unit P&L
    unit_income: dict[str, float] = defaultdict(float)
    unit_expenses: dict[str, float] = defaultdict(float)
    unit_ids_seen: set[str] = set()

    for t in txns:
        amt = float(t.get("amount", 0))
        mk = _month_key(t.get("date", ""))
        uid = t.get("leasing_unit_id") or "unallocated"
        unit_ids_seen.add(uid)

        if t.get("type") == "income":
            if mk in month_keys:
                income_by_month[mk] += amt
            total_income += amt
            unit_income[uid] += amt
        elif t.get("type") == "expense":
            if mk in month_keys:
                expense_by_month[mk] += amt
            total_expenses += amt
            unit_expenses[uid] += amt

    # Unit names
    real_ids = [uid for uid in unit_ids_seen if uid != "unallocated"]
    unit_map: dict[str, str] = {}
    if real_ids:
        units = sb.table("leasing_units").select("id,name,category").in_("id", real_ids).execute().data or []
        unit_map = {u["id"]: u["name"] for u in units}

    return {
        "period_start": start_date,
        "period_end": end_date,
        "total_income": round(total_income, 2),
        "total_expenses": round(total_expenses, 2),
        "net_profit": round(total_income - total_expenses, 2),
        "profit_margin": round((total_income - total_expenses) / total_income * 100, 1) if total_income else 0,
        "by_month": [
            {
                "month": mk,
                "label": _month_label(mk),
                "income": round(income_by_month[mk], 2),
                "expenses": round(expense_by_month[mk], 2),
                "net": round(income_by_month[mk] - expense_by_month[mk], 2),
            }
            for mk in month_keys
        ],
        "by_unit": sorted(
            [
                {
                    "unit_id": uid,
                    "unit_name": unit_map.get(uid, uid),
                    "income": round(unit_income[uid], 2),
                    "expenses": round(unit_expenses[uid], 2),
                    "net_profit": round(unit_income[uid] - unit_expenses[uid], 2),
                }
                for uid in unit_ids_seen
            ],
            key=lambda x: -x["net_profit"],
        ),
    }
