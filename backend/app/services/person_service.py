"""
DataOff — Servicio de Personas
Lógica de negocio para CRUD de personas y contactos.
"""
from datetime import datetime, timezone
from typing import List, Optional
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session, joinedload

from app.core.enums import SyncSource, SyncStatus
from app.models.person import Contact, Person
from app.models.user import User
from app.schemas.person import (
    ContactCreate,
    PersonCreate,
    PersonListResponse,
    PersonResponse,
    PersonUpdate,
    PaginatedPersons,
)


class PersonService:

    def create_person(
        self,
        db: Session,
        data: PersonCreate,
        current_user: User,
    ) -> Person:
        """Crea una persona desde la web (sync_source=WEB)."""
        now = datetime.now(timezone.utc)

        # Usar UUID proporcionado o generar uno nuevo
        person_id = data.id or uuid4()

        # Verificar duplicado por UUID (puede venir de APK)
        existing = db.query(Person).filter(Person.id == person_id).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Persona con ID {person_id} ya existe",
            )

        person = Person(
            id=person_id,
            user_id=current_user.id,
            first_name=data.first_name,
            last_name=data.last_name,
            document_type=data.document_type,
            document_number=data.document_number,
            birth_date=data.birth_date,
            gender=data.gender,
            address=data.address,
            city=data.city,
            department=data.department,
            country=data.country,
            notes=data.notes,
            captured_at=data.captured_at or now,
            synced_at=now,
            sync_source=data.sync_source,
            sync_status=SyncStatus.SYNCED,
        )
        db.add(person)
        db.flush()  # Para obtener el ID antes de crear contactos

        # Crear contactos asociados
        for contact_data in (data.contacts or []):
            contact = Contact(
                id=uuid4(),
                person_id=person.id,
                contact_type=contact_data.contact_type,
                contact_value=contact_data.contact_value,
                is_primary=contact_data.is_primary,
                label=contact_data.label,
                captured_at=now,
                synced_at=now,
                sync_source=SyncSource.WEB,
            )
            db.add(contact)

        db.flush()
        return person

    def get_person(self, db: Session, person_id: UUID) -> Person:
        """Obtiene una persona con sus contactos. 404 si no existe."""
        person = (
            db.query(Person)
            .options(joinedload(Person.contacts))
            .filter(Person.id == person_id, Person.is_deleted == False)
            .first()
        )
        if not person:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Persona {person_id} no encontrada",
            )
        return person

    def list_persons(
        self,
        db: Session,
        current_user: User,
        page: int = 1,
        page_size: int = 20,
        search: Optional[str] = None,
        city: Optional[str] = None,
    ) -> PaginatedPersons:
        """
        Lista personas con paginación y filtros.
        - ASESOR solo ve sus propias personas.
        - ADMIN/SUPER_ADMIN ven todas.
        """
        from app.core.enums import UserRole

        query = db.query(Person).filter(Person.is_deleted == False)

        # Filtro por rol
        if current_user.role == UserRole.ASESOR:
            query = query.filter(Person.user_id == current_user.id)

        # Filtro de búsqueda
        if search:
            search_term = f"%{search}%"
            query = query.filter(
                or_(
                    Person.first_name.ilike(search_term),
                    Person.last_name.ilike(search_term),
                    Person.document_number.ilike(search_term),
                )
            )

        if city:
            query = query.filter(Person.city.ilike(f"%{city}%"))

        # Ordenar por captured_at (fecha real de captura)
        query = query.order_by(Person.captured_at.desc())

        total = query.count()
        pages = (total + page_size - 1) // page_size
        items = query.offset((page - 1) * page_size).limit(page_size).all()

        # Contar contactos activos por persona
        person_ids = [p.id for p in items]
        contact_counts = {}
        if person_ids:
            counts = (
                db.query(Contact.person_id, func.count(Contact.id))
                .filter(
                    Contact.person_id.in_(person_ids),
                    Contact.is_deleted == False,
                )
                .group_by(Contact.person_id)
                .all()
            )
            contact_counts = {str(pid): count for pid, count in counts}

        list_items = []
        for person in items:
            item = PersonListResponse.model_validate(person)
            item.contacts_count = contact_counts.get(str(person.id), 0)
            list_items.append(item)

        return PaginatedPersons(
            items=list_items,
            total=total,
            page=page,
            page_size=page_size,
            pages=pages,
        )

    def update_person(
        self,
        db: Session,
        person_id: UUID,
        data: PersonUpdate,
        current_user: User,
    ) -> Person:
        """Actualización parcial de una persona."""
        from app.core.enums import UserRole

        person = self.get_person(db, person_id)

        # Verificar permisos
        if current_user.role == UserRole.ASESOR and person.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permiso para editar esta persona",
            )

        update_data = data.model_dump(exclude_unset=True, exclude_none=False)
        for field, value in update_data.items():
            # Aplicar regla de merge: no sobrescribir con vacío
            if value is not None and value != "":
                setattr(person, field, value)

        person.updated_at = datetime.now(timezone.utc)
        db.flush()
        return person

    def delete_person(
        self,
        db: Session,
        person_id: UUID,
        current_user: User,
    ) -> bool:
        """Soft delete de una persona."""
        from app.core.enums import UserRole

        person = self.get_person(db, person_id)

        if current_user.role == UserRole.ASESOR and person.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permiso para eliminar esta persona",
            )

        now = datetime.now(timezone.utc)
        person.is_deleted = True
        person.deleted_at = now
        db.flush()
        return True

    def add_contact(
        self,
        db: Session,
        data: ContactCreate,
        current_user: User,
    ) -> Contact:
        """Agrega un contacto a una persona existente."""
        # Verificar que la persona existe
        person = self.get_person(db, data.person_id)

        now = datetime.now(timezone.utc)
        contact = Contact(
            id=data.id or uuid4(),
            person_id=data.person_id,
            contact_type=data.contact_type,
            contact_value=data.contact_value,
            is_primary=data.is_primary,
            label=data.label,
            captured_at=data.captured_at or now,
            synced_at=now,
            sync_source=data.sync_source,
        )
        db.add(contact)
        db.flush()
        return contact


person_service = PersonService()
