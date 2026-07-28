"""Tasks router — manage property work items and recurring operational tasks."""

from __future__ import annotations

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


class TaskIn(BaseModel):
    title: str
    description: str | None = None
    property_id: str | None = None
    leasing_unit_id: str | None = None
    assigned_to: str | None = None
    priority: str = "medium"
    status: str = "open"
    due_date: str | None = None
    recurring_rule: str | None = None
    related_service_request_id: str | None = None


class TaskUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    assigned_to: str | None = None
    priority: str | None = None
    status: str | None = None
    due_date: str | None = None
    recurring_rule: str | None = None
    completed_at: str | None = None
    notes: str | None = None


@router.get("/")
async def list_tasks(
    property_id: str | None = None,
    unit_id: str | None = None,
    status: str | None = None,
    priority: str | None = None,
    assigned_to: str | None = None,
) -> list[dict[str, Any]]:
    sb = get_supabase()
    query = sb.table("tasks").select("*").order("due_date", desc=False).order("created_at", desc=False)
    if property_id:
        query = query.eq("property_id", property_id)
    if unit_id:
        query = query.eq("leasing_unit_id", unit_id)
    if status:
        query = query.eq("status", status)
    if priority:
        query = query.eq("priority", priority)
    if assigned_to:
        query = query.eq("assigned_to", assigned_to)
    return query.execute().data or []


@router.get("/{task_id}")
async def get_task(task_id: str) -> dict[str, Any]:
    res = get_supabase().table("tasks").select("*").eq("id", task_id).single().execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Task not found")
    return res.data


@router.post("/", status_code=201)
async def create_task(user_id: str, payload: TaskIn) -> dict[str, Any]:
    sb = get_supabase()
    _require_admin(sb, user_id, payload.leasing_unit_id)
    res = sb.table("tasks").insert(payload.model_dump(exclude_none=True)).execute()
    if not res.data:
        raise HTTPException(status_code=500, detail="Unable to create task")
    return res.data[0]


@router.patch("/{task_id}")
async def update_task(task_id: str, user_id: str, payload: TaskUpdate) -> dict[str, Any]:
    updates = {k: v for k, v in payload.model_dump(exclude_none=True).items()}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    sb = get_supabase()
    current = sb.table("tasks").select("leasing_unit_id").eq("id", task_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Task not found")
    _require_admin(sb, user_id, current.data[0].get("leasing_unit_id"))
    res = sb.table("tasks").update(updates).eq("id", task_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Task not found")
    return res.data[0]


@router.get("/summary")
async def task_summary() -> dict[str, Any]:
    tasks = list_tasks()
    return {
        "total": len(tasks),
        "open": len([t for t in tasks if t.get("status") == "open"]),
        "in_progress": len([t for t in tasks if t.get("status") == "in_progress"]),
        "completed": len([t for t in tasks if t.get("status") == "completed"]),
        "overdue": len(
            [
                t
                for t in tasks
                if t.get("status") not in {"completed", "cancelled"} and t.get("due_date") is not None
            ]
        ),
        "recurring": len([t for t in tasks if t.get("recurring_rule")]),
    }
