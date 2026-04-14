"""Application Service entry point."""

import logging

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.domain.exceptions import (
    ApplicationNotFoundError,
    InvalidStatusTransitionError,
    TemplateNotFoundError,
    ValidationError,
)
from app.interfaces.api.v1.routes.application_router import router as application_router
from app.interfaces.api.v1.routes.template_router import router as template_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Application Service",
    version="1.0.0",
    description="Manages rental application templates and submissions.",
)


# ---------------------------------------------------------------------------
# Exception handlers
# ---------------------------------------------------------------------------


@app.exception_handler(TemplateNotFoundError)
async def template_not_found_handler(request: Request, exc: TemplateNotFoundError) -> JSONResponse:
    return JSONResponse(
        status_code=404,
        content={"error": {"code": "TEMPLATE_NOT_FOUND", "message": str(exc)}},
    )


@app.exception_handler(ApplicationNotFoundError)
async def application_not_found_handler(
    request: Request, exc: ApplicationNotFoundError
) -> JSONResponse:
    return JSONResponse(
        status_code=404,
        content={"error": {"code": "APPLICATION_NOT_FOUND", "message": str(exc)}},
    )


@app.exception_handler(InvalidStatusTransitionError)
async def invalid_transition_handler(
    request: Request, exc: InvalidStatusTransitionError
) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={"error": {"code": "INVALID_STATUS_TRANSITION", "message": str(exc)}},
    )


@app.exception_handler(ValidationError)
async def validation_handler(request: Request, exc: ValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={"error": {"code": "VALIDATION_ERROR", "message": str(exc), "details": exc.details}},
    )


# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------

app.include_router(template_router, prefix="/api/v1/applications", tags=["Templates"])
app.include_router(application_router, prefix="/api/v1/applications", tags=["Applications"])


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------


@app.get("/health", tags=["Health"])
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "application-service"}
