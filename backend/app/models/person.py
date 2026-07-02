"""
DataOff — Modelos Person y Contact
Diseño normalizado: una persona puede tener N contactos.
Los contactos se ordenan por captured_at (fecha real de captura).
"""
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.enums import (
    ContactType,
    DocumentType,
    Gender,
    SyncSource,
    SyncStatus,
)
from app.db.base_model import Base, TimestampMixin, UUIDMixin


class Person(UUIDMixin, TimestampMixin, Base):
    """
    Entidad principal del sistema.
    
    Diseño crítico:
    - id: UUID generado en el dispositivo (no en la DB)
    - captured_at: fecha real de captura (inmutable)
    - synced_at: fecha de llegada al servidor (asignada por el servidor)
    - is_deleted: soft delete para preservar historial
    """
    __tablename__ = "persons"

    # ── Relación con usuario (asesor) ──────────────────────
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # ── Datos personales ───────────────────────────────────
    first_name: Mapped[str] = mapped_column(String(100), nullable=False)
    last_name: Mapped[str] = mapped_column(String(100), nullable=False)
    document_type: Mapped[DocumentType | None] = mapped_column(
        Enum(DocumentType, name="documenttype"), nullable=True
    )
    document_number: Mapped[str | None] = mapped_column(
        String(50), nullable=True, index=True
    )
    birth_date: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    gender: Mapped[Gender | None] = mapped_column(
        Enum(Gender, name="gender"), nullable=True
    )

    # ── Ubicación y Profesión ──────────────────────────────
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    city: Mapped[str | None] = mapped_column(String(100), nullable=True)
    department: Mapped[str | None] = mapped_column(String(100), nullable=True)
    country: Mapped[str] = mapped_column(String(100), default="Colombia", nullable=False)
    profession: Mapped[str | None] = mapped_column(String(150), nullable=True)

    # ── Notas ──────────────────────────────────────────────
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # ── Timestamps de sincronización (críticos para el Merge Engine) ──
    captured_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        comment="Fecha real de captura en el dispositivo. INMUTABLE.",
    )
    synced_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        comment="Fecha en que el registro llegó al servidor.",
    )

    # ── Metadatos de sincronización ────────────────────────
    sync_source: Mapped[SyncSource] = mapped_column(
        Enum(SyncSource, name="syncsource"),
        nullable=False,
        default=SyncSource.WEB,
    )
    sync_status: Mapped[SyncStatus] = mapped_column(
        Enum(SyncStatus, name="syncstatus"),
        nullable=False,
        default=SyncStatus.SYNCED,
    )
    device_id: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # ── Soft delete ────────────────────────────────────────
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # ── Relaciones ─────────────────────────────────────────
    user: Mapped["User"] = relationship("User", back_populates="persons")
    contacts: Mapped[list["Contact"]] = relationship(
        "Contact",
        back_populates="person",
        cascade="all, delete-orphan",
        order_by="Contact.captured_at",   # Ordenados por fecha real de captura
    )

    def __repr__(self) -> str:
        return f"<Person id={self.id} name={self.first_name} {self.last_name}>"


class Contact(UUIDMixin, TimestampMixin, Base):
    """
    Contacto de una persona. Tabla normalizada (no contacto1, contacto2...).
    Permite múltiples contactos por persona, ordenados por captured_at.
    """
    __tablename__ = "contacts"

    # ── Relación con persona ───────────────────────────────
    person_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("persons.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # ── Datos del contacto ─────────────────────────────────
    contact_type: Mapped[ContactType] = mapped_column(
        Enum(ContactType, name="contacttype"), nullable=False
    )
    contact_value: Mapped[str] = mapped_column(String(255), nullable=False)
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    label: Mapped[str | None] = mapped_column(
        String(100), nullable=True, comment="Ej: 'Trabajo', 'Casa', 'Celular'"
    )

    # ── Timestamps de sincronización ───────────────────────
    captured_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        comment="Fecha real de captura. INMUTABLE.",
    )
    synced_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    sync_source: Mapped[SyncSource] = mapped_column(
        Enum(SyncSource, name="syncsource"),
        nullable=False,
        default=SyncSource.WEB,
    )

    # ── Soft delete ────────────────────────────────────────
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # ── Relaciones ─────────────────────────────────────────
    person: Mapped["Person"] = relationship("Person", back_populates="contacts")

    def __repr__(self) -> str:
        return f"<Contact {self.contact_type}={self.contact_value}>"
