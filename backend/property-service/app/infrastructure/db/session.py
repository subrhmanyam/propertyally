"""Async SQLAlchemy engine and session factory.

Import `AsyncSessionFactory` wherever a database session is needed.
The engine is created once at application startup via `init_db()`.
"""

from __future__ import annotations

import logging
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

logger = logging.getLogger(__name__)

_engine: AsyncEngine | None = None
AsyncSessionFactory: async_sessionmaker[AsyncSession] | None = None


def init_db(database_url: str) -> None:
    """Create the async engine and session factory.  Call once during lifespan startup."""
    global _engine, AsyncSessionFactory

    _engine = create_async_engine(
        database_url,
        echo=False,
        pool_size=10,
        max_overflow=20,
        pool_pre_ping=True,
    )

    AsyncSessionFactory = async_sessionmaker(
        bind=_engine,
        class_=AsyncSession,
        expire_on_commit=False,
        autoflush=False,
        autocommit=False,
    )

    logger.info("Database engine initialised.")


async def close_db() -> None:
    """Dispose the async engine.  Call during lifespan shutdown."""
    global _engine
    if _engine is not None:
        await _engine.dispose()
        logger.info("Database engine disposed.")


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """Yield a transactional AsyncSession; rolls back on error, closes on exit."""
    if AsyncSessionFactory is None:
        raise RuntimeError("Database not initialised. Call init_db() first.")

    async with AsyncSessionFactory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
