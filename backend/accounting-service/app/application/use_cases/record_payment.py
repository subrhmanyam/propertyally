"""Use case: RecordPayment.

Delegates to the payment repository which calls the stored procedure
`accounting.record_payment_and_post_ledger` to atomically:
  1. Insert the payment row.
  2. Update the charge status (PAID or PARTIAL).
  3. Post a credit entry to the ledger.
"""

from __future__ import annotations

import logging
import uuid
from decimal import Decimal

from app.domain.entities.accounting import ChargeStatus, Payment, PaymentMethod
from app.domain.exceptions import (
    ChargeAlreadyPaidError,
    ChargeAlreadyWaivedError,
    ChargeNotFoundError,
    InsufficientFundsError,
    PaymentFailedError,
)
from app.domain.repositories.abstract_charge_repository import AbstractChargeRepository
from app.domain.repositories.abstract_payment_repository import AbstractPaymentRepository

logger = logging.getLogger(__name__)


class RecordPayment:
    """Record a tenant payment against a rent charge and post to the ledger."""

    def __init__(
        self,
        charge_repo: AbstractChargeRepository,
        payment_repo: AbstractPaymentRepository,
    ) -> None:
        self._charge_repo = charge_repo
        self._payment_repo = payment_repo

    async def execute(
        self,
        charge_id: uuid.UUID,
        tenant_id: uuid.UUID,
        amount: Decimal,
        payment_method: PaymentMethod,
        transaction_ref: str,
    ) -> Payment:
        # Validate amount
        if amount <= Decimal("0"):
            raise InsufficientFundsError()

        # Load the charge
        charge = await self._charge_repo.get_by_id(charge_id)
        if charge is None:
            raise ChargeNotFoundError(str(charge_id))

        if charge.status == ChargeStatus.PAID:
            raise ChargeAlreadyPaidError(str(charge_id))

        if charge.status == ChargeStatus.WAIVED:
            raise ChargeAlreadyWaivedError(str(charge_id))

        description = (
            f"Rent payment for {charge.period_month}/{charge.period_year} "
            f"— unit {charge.unit_id}"
        )

        try:
            payment_id = await self._payment_repo.record_payment_and_post_ledger(
                charge_id=charge_id,
                tenant_id=tenant_id,
                property_id=charge.property_id,
                amount=float(amount),
                method=payment_method.value,
                transaction_ref=transaction_ref,
                description=description,
            )
        except Exception as exc:
            logger.error("Stored procedure failed for charge %s: %s", charge_id, exc)
            raise PaymentFailedError(str(exc)) from exc

        payment = await self._payment_repo.get_by_id(payment_id)
        if payment is None:
            raise PaymentFailedError("Payment record not found after insert.")

        logger.info(
            "Payment %s recorded for charge %s — amount %.2f via %s",
            payment_id,
            charge_id,
            amount,
            payment_method.value,
        )
        return payment
