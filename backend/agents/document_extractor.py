"""
Agreement document extractor — Claude vision/document API.

Accepts a PDF or image of a lease/rental agreement and returns
structured JSON with all key fields pre-populated.

Table schema: supabase/migrations/005_unit_agreements.sql
"""

from __future__ import annotations

import base64
import json
import logging
import os
from typing import Any

import anthropic

logger = logging.getLogger(__name__)

_client: anthropic.Anthropic | None = None


def _get_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        _client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    return _client


_SYSTEM_PROMPT = """You are a property agreement parser for an Indian commercial real estate platform.
Extract all key fields from the uploaded lease/rental agreement document.
Return ONLY valid JSON — no explanation, no markdown fences.
For any field not found in the document, use null.
Dates must be in ISO format (YYYY-MM-DD).
Monetary amounts must be numbers (no currency symbols or commas).
"""

_EXTRACTION_PROMPT = """Extract all key fields from this lease/rental agreement and return them as JSON with exactly these keys:

{
  "tenant_name": string or null,
  "tenant_address": string or null,
  "total_area_sqft": number or null,
  "covered_area_sqft": number or null,
  "open_area_sqft": number or null,
  "monthly_rent": number or null,
  "monthly_maintenance": number or null,
  "security_deposit": number or null,
  "profit_sharing": string or null,
  "maintenance_paid_by": "owner" | "tenant" | "shared" or null,
  "furnishing_status": "fully_furnished" | "semi_furnished" | "unfurnished" or null,
  "car_parking_count": number or null,
  "amenities": [array of amenity strings, excluding car parking which has its own field],
  "lease_start_date": "YYYY-MM-DD" or null,
  "lease_end_date": "YYYY-MM-DD" or null,
  "notice_period_days": number or null,
  "payment_due_day": number or null,
  "tenant_gstin": string or null,
  "owner_name": string or null,
  "owner_address": string or null,
  "owner_gstin": string or null,
  "document_date": "YYYY-MM-DD" or null,
  "is_gst_applicable": boolean,
  "cgst_rate": number or null,
  "sgst_rate": number or null,
  "special_clauses": [array of notable clause strings, max 5]
}

Field notes:
- tenant_address / owner_address: the full registered/correspondence address for each party, not the leased property's address.
- profit_sharing: only for business/commercial leases with a revenue- or profit-share clause (e.g. "20% of gross monthly revenue to owner above ₹X"); null if the agreement is a flat rent with no sharing.
- maintenance_paid_by: who bears the recurring maintenance charge / upkeep expenses per the agreement — "owner", "tenant", or "shared" if split.
- furnishing_status: infer from any "furnished"/"semi-furnished"/"unfurnished" or fixtures/fittings clause; null if the document doesn't say.
"""


def _file_to_content_block(
    file_bytes: bytes, media_type: str, filename: str
) -> dict[str, Any]:
    """Build an Anthropic content block for a PDF or image."""
    data = base64.standard_b64encode(file_bytes).decode()

    if media_type == "application/pdf":
        return {
            "type": "document",
            "source": {
                "type": "base64",
                "media_type": "application/pdf",
                "data": data,
            },
        }

    # Image types: image/jpeg, image/png, image/webp, image/gif
    return {
        "type": "image",
        "source": {
            "type": "base64",
            "media_type": media_type,
            "data": data,
        },
    }


def extract_agreement_fields(
    file_bytes: bytes,
    media_type: str,
    filename: str,
) -> dict[str, Any]:
    """
    Send the document to Claude and return extracted agreement fields.

    Args:
        file_bytes:  Raw bytes of the uploaded file.
        media_type:  MIME type — 'application/pdf' | 'image/jpeg' | 'image/png' etc.
        filename:    Original filename (for logging).

    Returns:
        Dict of extracted fields matching the schema above.
    """
    client = _get_client()

    content_block = _file_to_content_block(file_bytes, media_type, filename)

    logger.info("Extracting agreement fields from %s (%s bytes)", filename, len(file_bytes))

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        system=_SYSTEM_PROMPT,
        messages=[
            {
                "role": "user",
                "content": [
                    content_block,
                    {"type": "text", "text": _EXTRACTION_PROMPT},
                ],
            }
        ],
    )

    raw_text = response.content[0].text.strip()
    logger.info("Extraction complete for %s", filename)

    try:
        fields: dict[str, Any] = json.loads(raw_text)
    except json.JSONDecodeError:
        # Claude occasionally wraps JSON in markdown — strip fences and retry
        cleaned = raw_text.removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        fields = json.loads(cleaned)

    return fields
