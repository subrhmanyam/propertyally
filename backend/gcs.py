"""Google Cloud Storage client + object-path convention for uploaded files.

Folder structure (see README note in documents.py):

    org_{org_id}/properties/{property_id}/{category}/{uuid}_{filename}
    org_{org_id}/general/{category}/{uuid}_{filename}          (no property)

Keying by org first keeps every tenant's files under one prefix — cheap to
list, easy to lock down with a bucket IAM condition per org if needed later.
Property comes next since "all files for this property" is the next most
common query. Category (leases, invoices, imports, other) keeps each
property's folder browsable instead of one flat dump.

The bucket is private (lease/tenant documents are PII) — reads go through
short-lived v4 signed URLs rather than public object URLs.
"""

from __future__ import annotations

import datetime
import os
import uuid

import google.auth
import google.auth.transport.requests
from google.cloud import storage

_SIGNED_URL_TTL = datetime.timedelta(hours=1)

_client: storage.Client | None = None
_bucket: storage.Bucket | None = None
_signing_credentials = None


def get_bucket() -> storage.Bucket:
    """Return a cached GCS bucket handle using Application Default Credentials.

    On Cloud Run this picks up the attached service account automatically.
    For local dev, run `gcloud auth application-default login` once, or set
    GOOGLE_APPLICATION_CREDENTIALS to a service-account key file.
    """
    global _client, _bucket
    if _bucket is None:
        _client = storage.Client()
        _bucket = _client.bucket(os.environ["GCS_BUCKET"])
    return _bucket


def _signing_email_and_token() -> tuple[str, str]:
    """Credentials on Cloud Run (and `gcloud auth application-default login`)
    have no private key to sign with locally, so we sign via the IAM
    SignBlob API instead — the caller just needs `roles/iam.serviceAccountTokenCreator`
    on GCS_SIGNING_SERVICE_ACCOUNT (see the migration/setup notes in documents.py).
    This target is a fixed service account rather than "whoever is calling",
    so the same code path works for the Cloud Run SA and for a developer's own
    gcloud login testing locally, as long as both are granted that role."""
    global _signing_credentials
    if _signing_credentials is None:
        _signing_credentials, _ = google.auth.default(
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
    _signing_credentials.refresh(google.auth.transport.requests.Request())
    email = os.environ.get("GCS_SIGNING_SERVICE_ACCOUNT") or getattr(
        _signing_credentials, "service_account_email", None
    )
    if not email or email == "default":
        raise RuntimeError(
            "Signed URL generation needs a target service account — set "
            "GCS_SIGNING_SERVICE_ACCOUNT or run with real service-account ADC."
        )
    return email, _signing_credentials.token


def build_object_path(
    *,
    org_id: str,
    category: str,
    filename: str,
    property_id: str | None = None,
) -> str:
    safe_category = category or "other"
    scope = f"properties/{property_id}" if property_id else "general"
    return f"org_{org_id}/{scope}/{safe_category}/{uuid.uuid4()}_{filename}"


def signed_url(object_path: str) -> str:
    email, token = _signing_email_and_token()
    blob = get_bucket().blob(object_path)
    return blob.generate_signed_url(
        version="v4",
        expiration=_SIGNED_URL_TTL,
        method="GET",
        service_account_email=email,
        access_token=token,
    )


def upload_bytes(
    *,
    org_id: str,
    category: str,
    filename: str,
    data: bytes,
    content_type: str,
    property_id: str | None = None,
) -> tuple[str, str]:
    """Upload bytes to GCS and return (object_path, signed_url)."""
    object_path = build_object_path(
        org_id=org_id, category=category, filename=filename, property_id=property_id
    )
    blob = get_bucket().blob(object_path)
    blob.upload_from_string(data, content_type=content_type)
    return object_path, signed_url(object_path)
