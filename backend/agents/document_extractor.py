"""
Agreement document extractor — Claude vision/document API.

Accepts a PDF or image of a lease/rental agreement and returns
structured JSON with all key fields pre-populated.

Supabase migration (run once in SQL editor):
────────────────────────────────────────────
create table if not exists unit_agreements (
  id                  uuid primary key default gen_random_uuid(),
  unit_id             text not null unique,
  document_name       text,
  document_type       text,           -- 'pdf' | 'image'
  tenant_name         text,
  total_area_sqft     float,
  covered_area_sqft   float,
  open_area_sqft      float,
  monthly_rent        float,
  monthly_maintenance float,
  security_deposit    float,
  lease_start_date    date,
  lease_end_date      date,
  notice_period_days  int,
  payment_due_day     int,
  tenant_gstin        text,
  owner_name          text,
  owner_gstin         text,
  special_clauses     jsonb default '[]',
  document_date       date,
  is_gst_applicable   boolean default false,
  cgst_rate           float,
  sgst_rate           float,
  raw_extraction      jsonb,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index if not exists idx_unit_agreements_unit on unit_agreements(unit_id);
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
  "property_name": string or null,
  "total_area_sqft": number or null,
  "covered_area_sqft": number or null,
  "open_area_sqft": number or null,
  "monthly_rent": number or null,
  "monthly_maintenance": number or null,
  "security_deposit": number or null,
  "lease_start_date": "YYYY-MM-DD" or null,
  "lease_end_date": "YYYY-MM-DD" or null,
  "notice_period_days": number or null,
  "payment_due_day": number or null,
  "tenant_gstin": string or null,
  "owner_name": string or null,
  "owner_gstin": string or null,
  "document_date": "YYYY-MM-DD" or null,
  "is_gst_applicable": boolean,
  "cgst_rate": number or null,
  "sgst_rate": number or null,
  "special_clauses": [array of notable clause strings, max 5]
}"""


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
