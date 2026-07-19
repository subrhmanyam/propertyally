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

GCS_PUBLIC_BUCKET is a separate, publicly-readable bucket for property/unit
photos — those aren't sensitive, and stable public URLs avoid re-signing on
every page load (see get_public_bucket / upload_public_bytes).
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
_public_bucket: storage.Bucket | None = None
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


def get_public_bucket() -> storage.Bucket:
    """The publicly-readable bucket for property/unit photos (GCS_PUBLIC_BUCKET) —
    separate from the private GCS_BUCKET used for lease documents/PII."""
    global _client, _public_bucket
    if _public_bucket is None:
        if _client is None:
            _client = storage.Client()
        _public_bucket = _client.bucket(os.environ["GCS_PUBLIC_BUCKET"])
    return _public_bucket


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


def generate_upload_url(object_path: str, content_type: str) -> str:
    """Signed PUT URL so a browser can upload straight to GCS, bypassing
    Cloud Run's ~32MB inbound request-body limit entirely for the file
    transfer itself. The caller must PUT with this exact Content-Type —
    GCS validates it against what the signature was generated for."""
    email, token = _signing_email_and_token()
    blob = get_bucket().blob(object_path)
    return blob.generate_signed_url(
        version="v4",
        expiration=_SIGNED_URL_TTL,
        method="PUT",
        content_type=content_type,
        service_account_email=email,
        access_token=token,
    )


def download_bytes(object_path: str) -> bytes:
    return get_bucket().blob(object_path).download_as_bytes()


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


def upload_public_bytes(
    *,
    org_id: str,
    category: str,
    filename: str,
    data: bytes,
    content_type: str,
    property_id: str | None = None,
) -> tuple[str, str]:
    """Upload bytes to the public bucket and return (object_path, public_url).
    No signing needed — GCS_PUBLIC_BUCKET grants allUsers read at the bucket
    level, so the URL is stable and never expires."""
    object_path = build_object_path(
        org_id=org_id, category=category, filename=filename, property_id=property_id
    )
    blob = get_public_bucket().blob(object_path)
    blob.upload_from_string(data, content_type=content_type)
    return object_path, blob.public_url


def delete_public_object(object_path: str) -> None:
    get_public_bucket().blob(object_path).delete()


def delete_object(object_path: str) -> None:
    get_bucket().blob(object_path).delete()
