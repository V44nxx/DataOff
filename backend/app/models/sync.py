"""
DataOff — Modelos de Autenticación y Auditoría
- RefreshToken: tokens de refresco con revocación
- SyncLog: auditoría de cada sincronización
"""
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.enums import SyncLogStatus
from app.db.base_model import Base, TimestampMixin, UUIDMixin


class RefreshToken(UUIDMixin, Base):
    """
    Token de refresco JWT almacenado en base de datos.
    Permite revocar tokens de dispositivos específicos.
    """
    __tablename__ = "refresh_tokens"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    token: Mapped[str] = mapped_column(String(500), unique=True, nullable=False)
    device_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # ── Relaciones ─────────────────────────────────────────
    user: Mapped["User"] = relationship("User", back_populates="refresh_tokens")

    def __repr__(self) -> str:
        return f"<RefreshToken user={self.user_id} revoked={self.revoked}>"


class SyncLog(UUIDMixin, Base):
    """
    Registro de auditoría de cada sincronización realizada.
    Permite rastrear qué dispositivo envió qué y cuándo.
    """
    __tablename__ = "sync_logs"

    user_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    device_id: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    synced_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    # ── Estadísticas ───────────────────────────────────────
    records_sent: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    records_inserted: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    records_updated: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    records_skipped: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    conflicts_resolved: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    status: Mapped[SyncLogStatus] = mapped_column(
        Enum(SyncLogStatus, name="synclogstatus"),
        nullable=False,
        default=SyncLogStatus.SUCCESS,
    )
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)

    # ── Detalle completo en JSON ────────────────────────────
    detail: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    # ── Relaciones ─────────────────────────────────────────
    user: Mapped["User"] = relationship("User", back_populates="sync_logs")

    def __repr__(self) -> str:
        return f"<SyncLog device={self.device_id} status={self.status} sent={self.records_sent}>"
