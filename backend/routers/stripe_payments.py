"""Stripe payments router — create Checkout Sessions and handle webhooks."""

from __future__ import annotations

import logging
import os
from typing import Any

import stripe
from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel

from db import get_supabase

logger = logging.getLogger(__name__)
router = APIRouter()

stripe.api_key = os.getenv("STRIPE_SECRET_KEY", "")
_WEBHOOK_SECRET = os.getenv("STRIPE_WEBHOOK_SECRET", "")


def _get_tenant(sb, user_id: str) -> dict:
    res = (
        sb.table("tenants")
        .select("id, first_name, last_name")
        .eq("auth_user_id", user_id)
        .limit(1)
        .execute()
    )
    if not res.data:
        raise HTTPException(status_code=404, detail="Tenant not found")
    return res.data[0]


# ── Create checkout session ───────────────────────────────────────────

class CheckoutIn(BaseModel):
    transaction_id: str
    success_url: str
    cancel_url: str


@router.post("/checkout")
async def create_checkout_session(user_id: str, payload: CheckoutIn) -> dict[str, str]:
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)

    # Verify the invoice belongs to this tenant
    tx = (
        sb.table("transactions")
        .select("id, amount, description, reference_no")
        .eq("id", payload.transaction_id)
        .eq("tenant_id", tenant["id"])
        .limit(1)
        .execute()
    )
    if not tx.data:
        raise HTTPException(status_code=404, detail="Invoice not found")
    txn = tx.data[0]

    amount_paise = int(txn["amount"] * 100)

    session = stripe.checkout.Session.create(
        payment_method_types=["card"],
        mode="payment",
        line_items=[
            {
                "price_data": {
                    "currency": "inr",
                    "unit_amount": amount_paise,
                    "product_data": {
                        "name": txn.get("description") or "Rent Invoice",
                        "metadata": {"reference_no": txn.get("reference_no", "")},
                    },
                },
                "quantity": 1,
            }
        ],
        success_url=payload.success_url,
        cancel_url=payload.cancel_url,
        metadata={
            "transaction_id": payload.transaction_id,
            "tenant_id": tenant["id"],
        },
    )

    # Record pending payment
    sb.table("stripe_payments").insert(
        {
            "transaction_id": payload.transaction_id,
            "tenant_id": tenant["id"],
            "stripe_session_id": session.id,
            "amount_paise": amount_paise,
            "currency": "inr",
            "status": "pending",
        }
    ).execute()

    return {"session_id": session.id, "url": session.url}


# ── Webhook ───────────────────────────────────────────────────────────

@router.post("/webhook", include_in_schema=False)
async def stripe_webhook(
    request: Request,
    stripe_signature: str = Header(None, alias="stripe-signature"),
) -> dict[str, str]:
    body = await request.body()

    try:
        if _WEBHOOK_SECRET:
            event = stripe.Webhook.construct_event(body, stripe_signature, _WEBHOOK_SECRET)
        else:
            # Dev mode — parse without signature verification
            import json
            event = stripe.Event.construct_from(json.loads(body), stripe.api_key)
    except (ValueError, stripe.error.SignatureVerificationError) as e:
        raise HTTPException(status_code=400, detail=str(e))

    sb = get_supabase()

    if event["type"] == "checkout.session.completed":
        session = event["data"]["object"]
        session_id = session["id"]
        transaction_id = session.get("metadata", {}).get("transaction_id")

        # Mark stripe_payments row paid
        sb.table("stripe_payments").update(
            {"status": "paid", "stripe_payment_intent_id": session.get("payment_intent"), "paid_at": "now()"}
        ).eq("stripe_session_id", session_id).execute()

        # Mark the transaction paid
        if transaction_id:
            sb.table("transactions").update({"status": "paid"}).eq("id", transaction_id).execute()

        logger.info("Payment completed: session=%s transaction=%s", session_id, transaction_id)

    elif event["type"] in ("checkout.session.expired", "payment_intent.payment_failed"):
        session_id = event["data"]["object"].get("id")
        if session_id:
            sb.table("stripe_payments").update({"status": "failed"}).eq(
                "stripe_session_id", session_id
            ).execute()

    return {"received": "ok"}


# ── Admin: payment history ────────────────────────────────────────────

@router.get("/")
async def list_payments(tenant_id: str | None = None) -> list[dict[str, Any]]:
    sb = get_supabase()
    query = (
        sb.table("stripe_payments")
        .select("*, tenants(first_name, last_name), transactions(description, reference_no)")
        .order("created_at", desc=True)
    )
    if tenant_id:
        query = query.eq("tenant_id", tenant_id)
    return query.execute().data or []


@router.get("/my")
async def my_payments(user_id: str) -> list[dict[str, Any]]:
    sb = get_supabase()
    tenant = _get_tenant(sb, user_id)
    res = (
        sb.table("stripe_payments")
        .select("*, transactions(description, reference_no)")
        .eq("tenant_id", tenant["id"])
        .order("created_at", desc=True)
        .execute()
    )
    return res.data or []
