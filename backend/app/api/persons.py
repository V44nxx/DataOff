"""
DataOff — Router de Personas y Contactos
"""
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.orm import Session

from app.core.dependencies import AsesorUser, CurrentUser, get_db
from app.schemas.person import (
    ContactCreate,
    ContactResponse,
    PaginatedPersons,
    PersonCreate,
    PersonResponse,
    PersonUpdate,
)
from app.services.person_service import person_service

router = APIRouter(prefix="/persons", tags=["Personas"])


@router.get("", response_model=PaginatedPersons, summary="Listar personas")
def list_persons(
    current_user: CurrentUser,
    db: Session = Depends(get_db),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    search: Optional[str] = Query(None, description="Buscar por nombre o documento"),
    city: Optional[str] = Query(None, description="Filtrar por ciudad"),
):
    """
    Lista personas con paginación.
    - ASESOR: solo sus propias personas.
    - ADMIN+: todas las personas.
    """
    return person_service.list_persons(
        db=db,
        current_user=current_user,
        page=page,
        page_size=page_size,
        search=search,
        city=city,
    )


@router.post(
    "",
    response_model=PersonResponse,
    summary="Crear o actualizar persona (upsert por número de documento)",
)
def create_person(
    data: PersonCreate,
    current_user: AsesorUser,
    db: Session = Depends(get_db),
    response: Response = None,
):
    """
    Crea una persona nueva. Si ya existe un registro con el mismo número
    de documento, actualiza sus datos y fusiona los nuevos contactos
    (sin eliminar los anteriores).
    """
    from app.models.person import Person as PersonModel
    # Detectar si la persona ya existe antes de llamar al servicio
    is_update = False
    if data.document_number and data.document_number.strip():
        existing = db.query(PersonModel).filter(
            PersonModel.document_number == data.document_number.strip(),
            PersonModel.is_deleted == False,
        ).first()
        is_update = existing is not None

    person = person_service.create_person(db=db, data=data, current_user=current_user)
    
    if response:
        response.status_code = status.HTTP_200_OK if is_update else status.HTTP_201_CREATED
    
    return person_service.get_person(db=db, person_id=person.id)


@router.get("/{person_id}", response_model=PersonResponse, summary="Obtener persona")
def get_person(
    person_id: UUID,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
):
    """Obtiene una persona con todos sus contactos."""
    return person_service.get_person(db=db, person_id=person_id)


@router.patch("/{person_id}", response_model=PersonResponse, summary="Actualizar persona")
def update_person(
    person_id: UUID,
    data: PersonUpdate,
    current_user: AsesorUser,
    db: Session = Depends(get_db),
):
    """Actualización parcial de una persona."""
    person = person_service.update_person(
        db=db, person_id=person_id, data=data, current_user=current_user
    )
    return person_service.get_person(db=db, person_id=person.id)


@router.delete("/{person_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_person(
    person_id: UUID,
    current_user: AsesorUser,
    db: Session = Depends(get_db),
):
    """Soft delete de una persona."""
    person_service.delete_person(db=db, person_id=person_id, current_user=current_user)


# ── Contactos ──────────────────────────────────────────────────
@router.post(
    "/{person_id}/contacts",
    response_model=ContactResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Agregar contacto",
)
def add_contact(
    person_id: UUID,
    data: ContactCreate,
    current_user: AsesorUser,
    db: Session = Depends(get_db),
):
    """Agrega un contacto a una persona existente."""
    data.person_id = person_id  # Asegurar consistencia
    return person_service.add_contact(db=db, data=data, current_user=current_user)
