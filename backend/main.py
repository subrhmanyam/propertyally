"""Bogineni Group — Property Management API (unified service)."""

from __future__ import annotations

import logging
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.requests import Request

from routers import (
    accounting, applications, auth, calendar, documents, leasing, listing_agent,
    listings, maintenance, notifications, reports, search, service_catalog,
    service_requests, stripe_payments, tasks, tenant, tenants,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(
    title="Bogineni Group API",
    description="Property management platform — leasing, tenants, accounting, maintenance, and more.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ---------------------------------------------------------------------------
# CORS — allow Flutter web and mobile clients
# ---------------------------------------------------------------------------

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("ALLOWED_ORIGINS", "*").split(","),
    # Local Flutter dev picks a random port each run, so a static origin in
    # ALLOWED_ORIGINS would break next session — allow any localhost port.
    allow_origin_regex=r"http://localhost:\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------

app.include_router(leasing.router,       prefix="/api/v1/leasing",       tags=["Leasing"])
app.include_router(tenants.router,       prefix="/api/v1/tenants",        tags=["Tenants"])
app.include_router(accounting.router,    prefix="/api/v1/accounting",     tags=["Accounting"])
app.include_router(maintenance.router,   prefix="/api/v1/maintenance",    tags=["Maintenance"])
app.include_router(applications.router,  prefix="/api/v1/applications",   tags=["Applications"])
app.include_router(listings.router,      prefix="/api/v1/listings",       tags=["Listings"])
app.include_router(tasks.router,         prefix="/api/v1/tasks",          tags=["Tasks"])
app.include_router(reports.router,       prefix="/api/v1/reports",        tags=["Reports"])
app.include_router(notifications.router, prefix="/api/v1/notifications",   tags=["Notifications"])
app.include_router(auth.router,          prefix="/api/v1/auth",            tags=["Auth"])
app.include_router(listing_agent.router, prefix="/api/v1/listing-agent",    tags=["Listing Agent"])
app.include_router(tenant.router,        prefix="/api/v1/tenant",          tags=["Tenant Portal"])
app.include_router(service_catalog.router, prefix="/api/v1/service-catalog", tags=["Service Catalog"])
app.include_router(service_requests.router, prefix="/api/v1/service-requests", tags=["Service Requests"])
app.include_router(stripe_payments.router,  prefix="/api/v1/payments",        tags=["Payments"])
app.include_router(calendar.router,         prefix="/api/v1/calendar",         tags=["Calendar"])
app.include_router(search.router,           prefix="/api/v1/search",            tags=["Search"])
app.include_router(documents.router,        prefix="/api/v1/documents",          tags=["Documents"])


# ---------------------------------------------------------------------------
# Global exception handler
# ---------------------------------------------------------------------------


@app.exception_handler(Exception)
async def unhandled_error_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.error("Unhandled error on %s: %s", request.url.path, exc, exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"error": {"code": "INTERNAL_SERVER_ERROR", "message": "An unexpected error occurred."}},
    )


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------


@app.get("/health", tags=["Health"])
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "bogi-api", "version": "1.0.0"}
