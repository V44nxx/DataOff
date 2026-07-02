"""
DataOff — Schemas de Persona y Contacto
Diseño: ContactResponse se incluye en PersonResponse (nested),
pero se puede crear/actualizar de forma independiente.
"""
from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field

from app.core.enums import (
    ContactType,
    DocumentType,
    Gender,
    SyncSource,
    SyncStatus,
)


# ════════════════════════════════════════════════════════════════
# CONTACT SCHEMAS
# ════════════════════════════════════════════════════════════════

class ContactBase(BaseModel):
    contact_type: ContactType
    contact_value: str = Field(..., min_length=1, max_length=255)
    is_primary: bool = False
    label: Optional[str] = Field(None, max_length=100)


class ContactCreate(ContactBase):
    """Para crear un contacto desde la web."""
    id: Optional[UUID] = None          # Puede venir de la APK
    person_id: UUID
    captured_at: Optional[datetime] = None   # Si viene de la APK, se respeta
    sync_source: SyncSource = SyncSource.WEB


class ContactUpdate(BaseModel):
    contact_type: Optional[ContactType] = None
    contact_value: Optional[str] = Field(None, min_length=1, max_length=255)
    is_primary: Optional[bool] = None
    label: Optional[str] = None


class ContactResponse(ContactBase):
    model_config = {"from_attributes": True}

    id: UUID
    person_id: UUID
    captured_at: datetime
    synced_at: Optional[datetime] = None
    sync_source: SyncSource
    is_deleted: bool
    created_at: datetime
    updated_at: datetime


# ════════════════════════════════════════════════════════════════
# PERSON SCHEMAS
# ════════════════════════════════════════════════════════════════

class PersonBase(BaseModel):
    first_name: str = Field(..., min_length=1, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)
    document_type: Optional[DocumentType] = None
    document_number: Optional[str] = Field(None, max_length=50)
    birth_date: Optional[datetime] = None
    gender: Optional[Gender] = None
    address: Optional[str] = None
    city: Optional[str] = Field(None, max_length=100)
    department: Optional[str] = Field(None, max_length=100)
    country: str = Field("Colombia", max_length=100)
    profession: Optional[str] = Field(None, max_length=150)
    notes: Optional[str] = None


class PersonCreate(PersonBase):
    """Para crear una persona desde la web."""
    id: Optional[UUID] = None          # UUID puede venir de la APK
    captured_at: Optional[datetime] = None
    sync_source: SyncSource = SyncSource.WEB
    contacts: Optional[List[ContactBase]] = []


class PersonUpdate(BaseModel):
    """Actualización parcial — todos los campos son opcionales."""
    first_name: Optional[str] = Field(None, min_length=1, max_length=100)
    last_name: Optional[str] = Field(None, min_length=1, max_length=100)
    document_type: Optional[DocumentType] = None
    document_number: Optional[str] = None
    birth_date: Optional[datetime] = None
    gender: Optional[Gender] = None
    address: Optional[str] = None
    city: Optional[str] = None
    department: Optional[str] = None
    country: Optional[str] = None
    profession: Optional[str] = None
    notes: Optional[str] = None


class PersonResponse(PersonBase):
    """Respuesta completa con contactos anidados."""
    model_config = {"from_attributes": True}

    id: UUID
    user_id: Optional[UUID] = None
    sync_source: SyncSource
    sync_status: SyncStatus
    captured_at: datetime
    synced_at: Optional[datetime] = None
    is_deleted: bool
    created_at: datetime
    updated_at: datetime
    contacts: List[ContactResponse] = []


class PersonListResponse(BaseModel):
    """Respuesta compacta para listados (sin contactos completos)."""
    model_config = {"from_attributes": True}

    id: UUID
    first_name: str
    last_name: str
    document_type: Optional[DocumentType] = None
    document_number: Optional[str] = None
    city: Optional[str] = None
    sync_source: SyncSource
    sync_status: SyncStatus
    captured_at: datetime
    synced_at: Optional[datetime] = None
    contacts_count: int = 0


# ── Paginación ──────────────────────────────────────────────────
class PaginatedPersons(BaseModel):
    items: List[PersonListResponse]
    total: int
    page: int
    page_size: int
    pages: int
