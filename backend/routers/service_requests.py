"""Service requests router — tenant submits service requests; admin manages them."""

from __future__ import annotations

import logging
import mimetypes
from typing import Any

from fastapi import APIRouter, File, HTTPException, Response, UploadFile
from pydantic import BaseModel

from auth_utils import require_org_admin_for_unit
from db import get_supabase

logger = logging.getLogger(__name__)
router = APIRouter()

_DECISION_STATUSES = {"Approved", "Review", "Declined"}
_DOCUMENT_MAX_BYTES = 20 * 1024 * 1024  # 20 MB


def _get_tenant(sb, user_id: str) -> dict:
    res = (
        sb.table("tenants")
        .select("id, leasing_unit_id")
        .eq("auth_user_id", user_id)
        .limit(1)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="Tenant record not found for this user")
    return res.data[0]


def _approver_for(row: dict) -> str | None:
    """Which party must sign off before this request can move to Approved.

    None means the requester is already the one bearing the cost, so no
    cross sign-off is needed. Otherwise, whichever side bears the expense
    must agree before the other side's request is approved.
    """
    bearer = row.get("expenses_borne_by")
    requester = row.get("requested_by")
    if bearer and requester and bearer != requester:
        return bearer
    return None


def _with_approval(row: dict) -> dict:
    row["approval_required_from"] = _approver_for(row)
    return row


# ── Notifications ───────────────────────────────────────────────────────
# Best-effort: a notification failure should never block the actual
# create/decide action, so every call site here swallows its own errors.

def _notify(user_id: str | None, title: str, body: str, action_url: str | None = None) -> None:
    if not user_id:
        return
    try:
        from services.notification_service import get_notification_service

        get_notification_service().send_in_app(
            user_id=user_id, title=title, body=body, type="info", action_url=action_url,
        )
    except Exception:
        logger.warning("Could not create notification for user %s", user_id, exc_info=True)


def _org_admin_user_ids(sb, org_id: str | None) -> list[str]:
    if not org_id:
        return []
    res = (
        sb.table("organization_members")
        .select("user_id")
        .eq("org_id", org_id)
        .eq("role", "admin")
        .execute()
    )
    return [r["user_id"] for r in (res.data or []) if r.get("user_id")]


def _tenant_auth_user_id(sb, tenant_id: str | None) -> str | None:
    if not tenant_id:
        return None
    res = sb.table("tenants").select("auth_user_id").eq("id", tenant_id).limit(1).execute()
    return res.data[0].get("auth_user_id") if res.data else None


def _unit_org_id(sb, unit_id: str | None) -> str | None:
    if not unit_id:
        return None
    res = sb.table("leasing_units").select("org_id").eq("id", unit_id).limit(1).execute()
    return res.data[0].get("org_id") if res.data else None


def _notify_owner(
    sb, unit_id: str | None, title: str, body: str, request_id: str | None = None
) -> None:
    action_url = f"/services?request_id={request_id}" if request_id else None
    for admin_user_id in _org_admin_user_ids(sb, _unit_org_id(sb, unit_id)):
        _notify(admin_user_id, title, body, action_url)


def _notify_tenant(
    sb, tenant_id: str | None, title: str, body: str, request_id: str | None = None
) -> None:
    action_url = f"/tenant/services?request_id={request_id}" if request_id else None
    _notify(_tenant_auth_user_id(sb, tenant_id), title, body, action_url)


# ── Tenant: submit and view own requests ──────────────────────────────

class ServiceRequestIn(BaseModel):
    service_id: str | None = None
    service_name: str | None = None
    description: str | None = None
    priority: str = "normal"
    photos: list[str] = []
    expenses_borne_by: str | None = None  # Owner | Tenant
    estimated_cost: float | None = None


@router.post("/", status_code=201)
async def create_service_request(user_id: str, payload: ServiceRequestIn) -> dict[str, Any]:
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)

    # Resolve service_name from catalog if only service_id given
    service_name = payload.service_name
    if not service_name and payload.service_id:
        cat = sb.table("service_catalog").select("name").eq("id", payload.service_id).limit(1).execute()
        service_name = cat.data[0]["name"] if cat.data else None

    row = {
        **payload.model_dump(),
        "service_name": service_name,
        "tenant_id": tenant["id"],
        "leasing_unit_id": tenant.get("leasing_unit_id"),
        "status": "Initiated",
        "requested_by": "Tenant",
    }
    res = sb.table("service_requests").insert(row).execute()
    created = res.data[0]

    if _approver_for(created) == "Owner":
        _notify_owner(
            sb,
            created.get("leasing_unit_id"),
            "Service request needs your approval",
            f'"{service_name or "A service request"}" was requested with the '
            "cost billed to you — approve, send back for review, or decline it.",
            request_id=created["id"],
        )

    return _with_approval(created)


@router.get("/my")
async def get_my_service_requests(user_id: str) -> list[dict[str, Any]]:
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)
    res = (
        sb.table("service_requests")
        .select("*, service_catalog(name, category), leasing_units(name), documents(*)")
        .eq("tenant_id", tenant["id"])
        .order("created_at", desc=True)
        .execute()
    )
    return [_with_approval(r) for r in (res.data or [])]


class TenantDecisionIn(BaseModel):
    status: str  # Approved | Review | Declined


@router.patch("/{request_id}/tenant-decision")
async def tenant_decide_service_request(
    request_id: str, user_id: str, payload: TenantDecisionIn
) -> dict[str, Any]:
    """Tenant-side response to an owner-initiated, tenant-funded request —
    the only party allowed to move it out of Initiated in that case."""
    if payload.status not in _DECISION_STATUSES:
        raise HTTPException(
            status_code=400,
            detail=f"Status must be one of {sorted(_DECISION_STATUSES)}.",
        )
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)

    current = sb.table("service_requests").select("*").eq("id", request_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Request not found")
    row = current.data[0]
    if row.get("tenant_id") != tenant["id"]:
        raise HTTPException(status_code=403, detail="This request does not belong to you.")
    if _approver_for(row) != "Tenant":
        raise HTTPException(status_code=409, detail="This request is not awaiting your approval.")

    updates: dict[str, Any] = {"status": payload.status}
    if payload.status == "Completed":
        updates["completed_at"] = "now()"
    res = sb.table("service_requests").update(updates).eq("id", request_id).execute()
    updated = res.data[0]

    verb = {"Approved": "approved", "Declined": "declined", "Review": "sent back for review"}[
        payload.status
    ]
    _notify_owner(
        sb,
        updated.get("leasing_unit_id"),
        f"Tenant {verb} a service request",
        f'"{updated.get("service_name") or "The service request"}" was {verb} by the tenant.',
        request_id=updated["id"],
    )

    return _with_approval(updated)


# ── Admin: create on behalf of any unit ──────────────────────────

class AdminServiceRequestIn(BaseModel):
    leasing_unit_id: str
    service_id: str | None = None
    service_name: str | None = None
    description: str | None = None
    priority: str = "normal"
    tenant_id: str | None = None
    expenses_borne_by: str | None = None  # Owner | Tenant
    estimated_cost: float | None = None
    initiated_date: str | None = None


@router.post("/admin", status_code=201)
async def admin_create_service_request(
    user_id: str, payload: AdminServiceRequestIn
) -> dict[str, Any]:
    sb = get_supabase()
    require_org_admin_for_unit(sb, user_id, payload.leasing_unit_id)

    service_name = payload.service_name
    if not service_name and payload.service_id:
        cat = sb.table("service_catalog").select("name").eq("id", payload.service_id).limit(1).execute()
        service_name = cat.data[0]["name"] if cat.data else None

    # Auto-link tenant if not provided — a unit can (in practice) have more
    # than one tenant row; prefer one with a real login so notifications can
    # actually reach them instead of silently no-op'ing on a null auth_user_id.
    tenant_id = payload.tenant_id
    if not tenant_id:
        t = (
            sb.table("tenants")
            .select("id, auth_user_id")
            .eq("leasing_unit_id", payload.leasing_unit_id)
            .execute()
        )
        candidates = t.data or []
        with_login = [c for c in candidates if c.get("auth_user_id")]
        chosen = with_login[0] if with_login else (candidates[0] if candidates else None)
        tenant_id = chosen["id"] if chosen else None

    row = {
        "leasing_unit_id": payload.leasing_unit_id,
        "service_id": payload.service_id,
        "service_name": service_name,
        "description": payload.description,
        "priority": payload.priority,
        "tenant_id": tenant_id,
        "status": "Initiated",
        "requested_by": "Owner",
        "expenses_borne_by": payload.expenses_borne_by,
        "estimated_cost": payload.estimated_cost,
    }
    if payload.initiated_date:
        row["initiated_date"] = payload.initiated_date
    res = sb.table("service_requests").insert(row).execute()
    created = res.data[0]

    if _approver_for(created) == "Tenant":
        _notify_tenant(
            sb,
            tenant_id,
            "Service request needs your approval",
            f'"{service_name or "A service request"}" was requested for your unit with '
            "the cost billed to you — approve, send back for review, or decline it.",
            request_id=created["id"],
        )
    else:
        # Owner-billed (or bearer unset) — no cross-party approval needed, but
        # the org's admins should still see that a new request was logged.
        _notify_owner(
            sb,
            payload.leasing_unit_id,
            "New service request created",
            f'"{service_name or "A service request"}" was created for this property, '
            "billed to the owner.",
            request_id=created["id"],
        )

    return _with_approval(created)


# ── Admin: all requests ───────────────────────────────────────────────

@router.get("/")
async def list_service_requests(
    status: str | None = None,
    unit_id: str | None = None,
) -> list[dict[str, Any]]:
    sb = get_supabase()
    query = (
        sb.table("service_requests")
        .select("*, service_catalog(name, category), tenants(first_name, last_name), leasing_units(name), documents(*)")
        .order("created_at", desc=True)
    )
    if status:
        query = query.eq("status", status)
    if unit_id:
        query = query.eq("leasing_unit_id", unit_id)
    return [_with_approval(r) for r in (query.execute().data or [])]


@router.get("/{request_id}")
async def get_service_request(request_id: str) -> dict[str, Any]:
    res = (
        get_supabase()
        .table("service_requests")
        .select("*, service_catalog(name, category), tenants(first_name, last_name), leasing_units(name), documents(*)")
        .eq("id", request_id)
        .limit(1)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="Request not found")
    return _with_approval(res.data[0])


class ServiceRequestUpdate(BaseModel):
    status: str | None = None
    assigned_to: str | None = None
    scheduled_at: str | None = None
    admin_notes: str | None = None
    tenant_rating: int | None = None
    expenses_borne_by: str | None = None
    estimated_cost: float | None = None
    initiated_date: str | None = None


@router.patch("/{request_id}")
async def update_service_request(
    request_id: str, user_id: str, payload: ServiceRequestUpdate
) -> dict[str, Any]:
    """Owner/admin-side update. Only an admin of the owning organization may
    call this — a tenant hitting this endpoint directly (instead of going
    through /tenant-decision) is rejected regardless of what they pass.
    Approving a request that's actually pending the tenant's sign-off
    (owner-initiated, tenant-funded) is also rejected either way."""
    updates = {k: v for k, v in payload.model_dump().items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")

    sb = get_supabase()
    current = sb.table("service_requests").select("*").eq("id", request_id).limit(1).execute()
    if not current.data:
        raise HTTPException(status_code=404, detail="Request not found")
    current_row = current.data[0]

    require_org_admin_for_unit(sb, user_id, current_row.get("leasing_unit_id"))

    if payload.status == "Approved" and _approver_for(current_row) == "Tenant":
        raise HTTPException(
            status_code=409,
            detail="Tenant approval is required before this can be approved.",
        )

    if payload.status == "Completed":
        updates["completed_at"] = "now()"
    res = sb.table("service_requests").update(updates).eq("id", request_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Request not found")
    updated = res.data[0]

    if payload.status in _DECISION_STATUSES:
        verb = {"Approved": "approved", "Declined": "declined", "Review": "sent back for review"}[
            payload.status
        ]
        _notify_tenant(
            sb,
            updated.get("tenant_id"),
            f"Your service request was {verb}",
            f'"{updated.get("service_name") or "Your service request"}" was {verb} by the owner.',
            request_id=updated["id"],
        )

    return _with_approval(updated)


# ── Supporting documents (invoices, quotes, receipts) ─────────────────

@router.post("/{request_id}/documents", status_code=201)
async def upload_service_request_document(
    request_id: str, file: UploadFile = File(...)
) -> dict[str, Any]:
    import gcs

    sb = get_supabase()
    req_res = (
        sb.table("service_requests")
        .select("leasing_unit_id")
        .eq("id", request_id)
        .limit(1)
        .execute()
    )
    if not req_res.data:
        raise HTTPException(status_code=404, detail="Request not found")
    unit_id = req_res.data[0].get("leasing_unit_id")

    org_id = None
    if unit_id:
        unit_res = sb.table("leasing_units").select("org_id").eq("id", unit_id).limit(1).execute()
        org_id = unit_res.data[0].get("org_id") if unit_res.data else None
    if not org_id:
        raise HTTPException(
            status_code=400,
            detail="Could not resolve an organization for this request's property.",
        )

    file_bytes = await file.read()
    if len(file_bytes) > _DOCUMENT_MAX_BYTES:
        raise HTTPException(status_code=413, detail="File too large (max 20 MB).")

    media_type = file.content_type or "application/octet-stream"
    storage_path, file_url = gcs.upload_bytes(
        org_id=org_id,
        category="expense",
        filename=file.filename or "document",
        data=file_bytes,
        content_type=media_type,
        property_id=unit_id,
    )

    row = {
        "name": file.filename or "document",
        "type": "expense",
        "file_url": file_url,
        "file_size": len(file_bytes),
        "leasing_unit_id": unit_id,
        "org_id": org_id,
        "storage_path": storage_path,
        "service_request_id": request_id,
    }
    res = sb.table("documents").insert(row).execute()
    return res.data[0]


@router.get("/documents/{document_id}/download")
async def download_service_request_document(document_id: str) -> Response:
    """Streams the file through our own API rather than exposing the GCS
    signed URL stored in documents.file_url — that URL leaks the bucket
    and object path (org/property ids) and is a working credential for
    the private bucket in its own right. Proxying keeps the browser on
    our domain and re-reads from storage fresh on every request."""
    import gcs

    sb = get_supabase()
    doc_res = (
        sb.table("documents")
        .select("storage_path, name")
        .eq("id", document_id)
        .limit(1)
        .execute()
    )
    if not doc_res.data or not doc_res.data[0].get("storage_path"):
        raise HTTPException(status_code=404, detail="Document not found")
    row = doc_res.data[0]

    try:
        file_bytes = gcs.download_bytes(row["storage_path"])
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Could not read document from storage: {exc}")

    filename = row.get("name") or "document"
    media_type = mimetypes.guess_type(filename)[0] or "application/octet-stream"
    return Response(
        content=file_bytes,
        media_type=media_type,
        headers={"Content-Disposition": f'inline; filename="{filename}"'},
    )


@router.delete("/{request_id}/documents/{document_id}", status_code=204)
async def delete_service_request_document(request_id: str, document_id: str) -> None:
    import gcs

    sb = get_supabase()
    doc_res = (
        sb.table("documents")
        .select("storage_path")
        .eq("id", document_id)
        .eq("service_request_id", request_id)
        .limit(1)
        .execute()
    )
    if not doc_res.data:
        raise HTTPException(status_code=404, detail="Document not found")

    sb.table("documents").delete().eq("id", document_id).execute()

    storage_path = doc_res.data[0].get("storage_path")
    if storage_path:
        try:
            gcs.delete_object(storage_path)
        except Exception:
            pass
