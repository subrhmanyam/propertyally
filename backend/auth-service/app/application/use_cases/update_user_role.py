"""UpdateUserRoleUseCase — admin-only role assignment."""

from __future__ import annotations

import logging
from dataclasses import dataclass
from uuid import UUID

from app.domain.entities.user import User, UserRole
from app.domain.exceptions import ForbiddenError, UserNotFoundError
from app.domain.repositories.abstract_user_repository import AbstractUserRepository

logger = logging.getLogger(__name__)


@dataclass
class UpdateUserRoleInput:
    target_user_id: UUID
    new_role: UserRole
    requesting_user_role: UserRole


class UpdateUserRoleUseCase:
    """Only super_admin may change another user's role."""

    def __init__(self, user_repo: AbstractUserRepository) -> None:
        self._user_repo = user_repo

    async def execute(self, inp: UpdateUserRoleInput) -> User:
        if inp.requesting_user_role != UserRole.SUPER_ADMIN:
            raise ForbiddenError("Only super_admin can change user roles.")

        target = await self._user_repo.get_by_id(inp.target_user_id)
        if target is None:
            raise UserNotFoundError(str(inp.target_user_id))

        updated = await self._user_repo.update(inp.target_user_id, role=inp.new_role.value)
        logger.info(
            "Role updated: user=%s new_role=%s", inp.target_user_id, inp.new_role.value
        )
        return updated
