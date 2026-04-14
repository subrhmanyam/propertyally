"""Auth API router — all endpoints under /api/v1/auth."""

from __future__ import annotations

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from supabase import Client

from app.application.use_cases.change_password import (
    ChangePasswordInput,
    ChangePasswordUseCase,
)
from app.application.use_cases.login_user import LoginUserInput, LoginUserUseCase
from app.application.use_cases.logout_user import LogoutUserInput, LogoutUserUseCase
from app.application.use_cases.refresh_token import RefreshTokenInput, RefreshTokenUseCase
from app.application.use_cases.register_user import RegisterUserInput, RegisterUserUseCase
from app.application.use_cases.request_password_reset import (
    RequestPasswordResetInput,
    RequestPasswordResetUseCase,
)
from app.application.use_cases.reset_password import ResetPasswordInput, ResetPasswordUseCase
from app.application.use_cases.update_user_role import (
    UpdateUserRoleInput,
    UpdateUserRoleUseCase,
)
from app.application.use_cases.validate_token import ValidateTokenInput, ValidateTokenUseCase
from app.domain.entities.user import User, UserRole
from app.domain.exceptions import AuthServiceError, ForbiddenError
from app.interfaces.dependencies import (
    CurrentUser,
    get_refresh_token_repository,
    get_supabase,
    get_user_repository,
)
from app.infrastructure.db.repositories.refresh_token_repository import (
    RefreshTokenRepository,
)
from app.infrastructure.db.repositories.user_repository import UserRepository
from app.infrastructure.db.session import get_async_session
from app.interfaces.schemas.requests.auth_requests import (
    ChangePasswordRequest,
    LoginRequest,
    RefreshRequest,
    RegisterRequest,
    RequestPasswordResetRequest,
    ResetPasswordRequest,
    UpdateProfileRequest,
    UpdateRoleRequest,
    ValidateTokenRequest,
)
from app.interfaces.schemas.responses.auth_responses import (
    AuthResponse,
    MessageResponse,
    TokenResponse,
    UserResponse,
    ValidateTokenResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/auth", tags=["auth"])


def _domain_error_to_http(exc: AuthServiceError) -> HTTPException:
    return HTTPException(
        status_code=exc.http_status,
        detail={"error": {"code": exc.code, "message": exc.message}},
    )


# ---------------------------------------------------------------------------
# POST /register
# ---------------------------------------------------------------------------


@router.post(
    "/register",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user account",
)
async def register(
    body: RegisterRequest,
    user_repo: UserRepository = Depends(get_user_repository),
    supabase: Client = Depends(get_supabase),
) -> AuthResponse:
    use_case = RegisterUserUseCase(user_repo=user_repo, supabase=supabase)
    try:
        result = await use_case.execute(
            RegisterUserInput(
                email=body.email,
                password=body.password,
                full_name=body.full_name,
                role=body.role,
            )
        )
    except AuthServiceError as exc:
        raise _domain_error_to_http(exc) from exc

    return AuthResponse(
        user=UserResponse.model_validate(result.user),
        tokens=TokenResponse(
            access_token=result.tokens.access_token,
            refresh_token=result.tokens.refresh_token,
        ),
    )


# ---------------------------------------------------------------------------
# POST /login
# ---------------------------------------------------------------------------


@router.post(
    "/login",
    response_model=AuthResponse,
    summary="Authenticate and receive JWT tokens",
)
async def login(
    body: LoginRequest,
    user_repo: UserRepository = Depends(get_user_repository),
    supabase: Client = Depends(get_supabase),
) -> AuthResponse:
    use_case = LoginUserUseCase(user_repo=user_repo, supabase=supabase)
    try:
        result = await use_case.execute(
            LoginUserInput(email=body.email, password=body.password)
        )
    except AuthServiceError as exc:
        raise _domain_error_to_http(exc) from exc

    return AuthResponse(
        user=UserResponse.model_validate(result.user),
        tokens=TokenResponse(
            access_token=result.tokens.access_token,
            refresh_token=result.tokens.refresh_token,
        ),
    )


# ---------------------------------------------------------------------------
# POST /refresh
# ---------------------------------------------------------------------------


@router.post(
    "/refresh",
    response_model=TokenResponse,
    summary="Exchange a refresh token for a new token pair",
)
async def refresh(
    body: RefreshRequest,
    supabase: Client = Depends(get_supabase),
) -> TokenResponse:
    use_case = RefreshTokenUseCase(supabase=supabase)
    try:
        result = await use_case.execute(RefreshTokenInput(refresh_token=body.refresh_token))
    except AuthServiceError as exc:
        raise _domain_error_to_http(exc) from exc

    return TokenResponse(
        access_token=result.tokens.access_token,
        refresh_token=result.tokens.refresh_token,
    )


# ---------------------------------------------------------------------------
# POST /logout
# ---------------------------------------------------------------------------


@router.post(
    "/logout",
    response_model=MessageResponse,
    summary="Invalidate the current session and revoke all refresh tokens",
)
async def logout(
    current_user: CurrentUser,
    credentials_header: str = "",
    rt_repo: RefreshTokenRepository = Depends(get_refresh_token_repository),
    supabase: Client = Depends(get_supabase),
) -> MessageResponse:
    # Extract raw token from the Authorization header via the request
    # We re-use the CurrentUser dependency which already validated the token;
    # the token itself is available from the dependency but we need it for sign_out.
    # We handle sign_out best-effort inside the use case.
    use_case = LogoutUserUseCase(refresh_token_repo=rt_repo, supabase=supabase)
    try:
        # Access token not needed for local DB cleanup; Supabase sign_out is best-effort
        await use_case.execute(
            LogoutUserInput(access_token="", user_id=current_user.id)
        )
    except AuthServiceError as exc:
        raise _domain_error_to_http(exc) from exc

    return MessageResponse(message="Successfully logged out.")


# ---------------------------------------------------------------------------
# GET /me
# ---------------------------------------------------------------------------


@router.get(
    "/me",
    response_model=UserResponse,
    summary="Get the current authenticated user's profile",
)
async def get_me(current_user: CurrentUser) -> UserResponse:
    return UserResponse.model_validate(current_user)


# ---------------------------------------------------------------------------
# PUT /me
# ---------------------------------------------------------------------------


@router.put(
    "/me",
    response_model=UserResponse,
    summary="Update the current user's profile",
)
async def update_profile(
    body: UpdateProfileRequest,
    current_user: CurrentUser,
    user_repo: UserRepository = Depends(get_user_repository),
) -> UserResponse:
    fields: dict[str, object] = {}
    if body.full_name is not None:
        fields["full_name"] = body.full_name

    if not fields:
        return UserResponse.model_validate(current_user)

    try:
        updated = await user_repo.update(current_user.id, **fields)
    except AuthServiceError as exc:
        raise _domain_error_to_http(exc) from exc

    return UserResponse.model_validate(updated)


# ---------------------------------------------------------------------------
# PUT /password
# ---------------------------------------------------------------------------


@router.put(
    "/password",
    response_model=MessageResponse,
    summary="Change password (requires current password)",
)
async def change_password(
    body: ChangePasswordRequest,
    current_user: CurrentUser,
    user_repo: UserRepository = Depends(get_user_repository),
    supabase: Client = Depends(get_supabase),
) -> MessageResponse:
    # We need the raw Bearer token to set session context in Supabase
    # The token was already validated by get_current_user; we pass empty string
    # and let the use case handle the re-auth via sign_in_with_password.
    use_case = ChangePasswordUseCase(user_repo=user_repo, supabase=supabase)
    try:
        await use_case.execute(
            ChangePasswordInput(
                user_id=current_user.id,
                current_password=body.current_password,
                new_password=body.new_password,
                access_token="",  # re-auth done via sign_in inside use case
            )
        )
    except AuthServiceError as exc:
        raise _domain_error_to_http(exc) from exc

    return MessageResponse(message="Password changed successfully.")


# ---------------------------------------------------------------------------
# POST /password/reset
# ---------------------------------------------------------------------------


@router.post(
    "/password/reset",
    response_model=MessageResponse,
    summary="Request a password reset OTP",
)
async def request_password_reset(
    body: RequestPasswordResetRequest,
    user_repo: UserRepository = Depends(get_user_repository),
    supabase: Client = Depends(get_supabase),
    session: AsyncSession = Depends(get_async_session),
) -> MessageResponse:
    use_case = RequestPasswordResetUseCase(
        user_repo=user_repo, supabase=supabase, session=session
    )
    # Always return 200 (no user-enumeration)
    try:
        await use_case.execute(RequestPasswordResetInput(email=body.email))
    except Exception:
        pass  # swallow all errors silently

    return MessageResponse(
        message="If that email is registered, a reset code has been sent."
    )


# ---------------------------------------------------------------------------
# POST /password/confirm
# ---------------------------------------------------------------------------


@router.post(
    "/password/confirm",
    response_model=MessageResponse,
    summary="Confirm password reset with OTP",
)
async def confirm_password_reset(
    body: ResetPasswordRequest,
    user_repo: UserRepository = Depends(get_user_repository),
    supabase: Client = Depends(get_supabase),
    session: AsyncSession = Depends(get_async_session),
) -> MessageResponse:
    use_case = ResetPasswordUseCase(user_repo=user_repo, supabase=supabase, session=session)
    try:
        await use_case.execute(
            ResetPasswordInput(
                email=body.email,
                otp=body.otp,
                new_password=body.new_password,
            )
        )
    except AuthServiceError as exc:
        raise _domain_error_to_http(exc) from exc

    return MessageResponse(message="Password has been reset successfully.")


# ---------------------------------------------------------------------------
# PATCH /users/{id}/role
# ---------------------------------------------------------------------------


@router.patch(
    "/users/{user_id}/role",
    response_model=UserResponse,
    summary="Update a user's role (super_admin only)",
)
async def update_user_role(
    user_id: UUID,
    body: UpdateRoleRequest,
    current_user: CurrentUser,
    user_repo: UserRepository = Depends(get_user_repository),
) -> UserResponse:
    use_case = UpdateUserRoleUseCase(user_repo=user_repo)
    try:
        updated = await use_case.execute(
            UpdateUserRoleInput(
                target_user_id=user_id,
                new_role=body.role,
                requesting_user_role=current_user.role,
            )
        )
    except AuthServiceError as exc:
        raise _domain_error_to_http(exc) from exc

    return UserResponse.model_validate(updated)


# ---------------------------------------------------------------------------
# POST /validate  (inter-service token validation)
# ---------------------------------------------------------------------------


@router.post(
    "/validate",
    response_model=ValidateTokenResponse,
    summary="Validate a Bearer token (for other services)",
)
async def validate_token(
    body: ValidateTokenRequest,
    user_repo: UserRepository = Depends(get_user_repository),
    supabase: Client = Depends(get_supabase),
) -> ValidateTokenResponse:
    use_case = ValidateTokenUseCase(user_repo=user_repo, supabase=supabase)
    try:
        result = await use_case.execute(ValidateTokenInput(access_token=body.access_token))
    except AuthServiceError as exc:
        raise _domain_error_to_http(exc) from exc

    return ValidateTokenResponse(
        valid=True,
        user=UserResponse.model_validate(result.user),
        supabase_uid=result.supabase_uid,
        email=result.email,
    )
