"""
DataOff — Modelo Base SQLAlchemy
Todos los modelos heredan de esta clase base que provee:
- UUID como PK (generado en Python, no en la DB)
- created_at, updated_at automáticos
"""
import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    """Base declarativa de SQLAlchemy 2.0."""
    pass


class TimestampMixin:
    """
    Mixin que agrega created_at y updated_at a cualquier modelo.
    updated_at se actualiza automáticamente en cada UPDATE.
    """
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class UUIDMixin:
    """
    Mixin que usa UUID v4 como clave primaria.
    El UUID se genera en Python (no en PostgreSQL) para que la APK
    pueda crear IDs offline y luego sincronizarlos sin conflictos.
    """
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        nullable=False,
    )
