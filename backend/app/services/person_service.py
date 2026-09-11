"""
DataOff — Servicio de Personas
Lógica de negocio para CRUD de personas y contactos.
"""
from datetime import datetime, timedelta, timezone
from typing import Any, List, Optional
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session, joinedload

from app.core.enums import ContactType, SyncSource, SyncStatus
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


def _normalize_contact_type(raw: Any) -> ContactType:
    """Normaliza cualquier texto de tipo de contacto al enum oficial de PostgreSQL."""
    if isinstance(raw, ContactType):
        return raw
    if not raw:
        return ContactType.PHONE
    val = str(raw).lower().strip()
    if "tel" in val or "cel" in val or "mov" in val or "phone" in val:
        return ContactType.PHONE
    if "mail" in val or "correo" in val:
        return ContactType.EMAIL
    if "what" in val:
        return ContactType.WHATSAPP
    if "face" in val:
        return ContactType.FACEBOOK
    if "insta" in val:
        return ContactType.INSTAGRAM
    try:
        return ContactType(val)
    except ValueError:
        return ContactType.OTHER


def _apply_contacts_escalera(
    db: Session,
    person: Person,
    incoming_contacts: list[Any],
    now: datetime,
    sync_source: SyncSource = SyncSource.WEB,
) -> list[Contact]:
    """
    Aplica la regla de escalera (máximo 3 contactos activos por persona):
    1. Filtra números ya existentes para evitar duplicados.
    2. Los nuevos contactos toman la posición superior (Puesto 1).
    3. Los contactos previos se desplazan hacia abajo (Puesto 2 y 3).
    4. Si hay más de 3 contactos activos, los más antiguos se marcan como
       is_deleted = True (desalojo FIFO).
    5. Re-etiqueta los hasta 3 contactos activos conservados:
       - Puesto 1 -> 'Contacto 1' (is_primary = True)
       - Puesto 2 -> 'Contacto 2' (is_primary = False)
       - Puesto 3 -> 'Contacto 3' (is_primary = False)
    """
    active_contacts = (
        db.query(Contact)
        .filter(
            Contact.person_id == person.id,
            Contact.is_deleted == False,
        )
        .all()
    )

    existing_values = {
        c.contact_value.strip().lower()
        for c in active_contacts
        if c.contact_value
    }

    # Determinar el timestamp base garantizado estrictamente más reciente que cualquier existente
    existing_timestamps = [
        c.captured_at for c in active_contacts if c.captured_at
    ]
    max_existing_dt = max(existing_timestamps, default=now)
    if max_existing_dt.tzinfo is None:
        max_existing_dt = max_existing_dt.replace(tzinfo=timezone.utc)
    now_utc = now if now.tzinfo is not None else now.replace(tzinfo=timezone.utc)
    base_ts = max(now_utc, max_existing_dt)

    newly_added: list[Contact] = []
    incoming_list = list(incoming_contacts or [])

    for i, cd in enumerate(incoming_list):
        val = getattr(cd, "contact_value", None)
        if val is None and isinstance(cd, dict):
            val = cd.get("contact_value")
        val = str(val or "").strip()
        if not val or val.lower() in existing_values:
            continue
        existing_values.add(val.lower())

        ctype = getattr(cd, "contact_type", None)
        if ctype is None and isinstance(cd, dict):
            ctype = cd.get("contact_type")
        ctype = _normalize_contact_type(ctype)

        cid = getattr(cd, "id", None)
        if cid is None and isinstance(cd, dict):
            cid = cd.get("id")
        cid = cid or uuid4()

        cap_at = getattr(cd, "captured_at", None)
        if cap_at is None and isinstance(cd, dict):
            cap_at = cd.get("captured_at")

        # Asignar timestamp strictly newer para que el nuevo tome Puesto 1.
        # Si vienen múltiples nuevos, el primero en la lista toma el timestamp más alto.
        offset_seconds = len(incoming_list) - i
        assigned_cap_at = base_ts + timedelta(seconds=offset_seconds)
        if cap_at:
            if isinstance(cap_at, str):
                try:
                    parsed_dt = datetime.fromisoformat(cap_at.replace("Z", "+00:00"))
                    if parsed_dt.tzinfo is None:
                        parsed_dt = parsed_dt.replace(tzinfo=timezone.utc)
                    if parsed_dt > base_ts:
                        assigned_cap_at = parsed_dt
                except ValueError:
                    pass
            elif isinstance(cap_at, datetime):
                parsed_dt = cap_at if cap_at.tzinfo is not None else cap_at.replace(tzinfo=timezone.utc)
                if parsed_dt > base_ts:
                    assigned_cap_at = parsed_dt

        new_c = Contact(
            id=cid,
            person_id=person.id,
            contact_type=ctype,
            contact_value=val,
            is_primary=False,
            label=None,
            captured_at=assigned_cap_at,
            synced_at=now,
            sync_source=sync_source,
            is_deleted=False,
        )
        db.add(new_c)
        newly_added.append(new_c)

    all_active = [c for c in (newly_added + active_contacts) if not c.is_deleted]

    def _get_ts(c: Contact) -> float:
        dt = c.captured_at or c.created_at or now
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc).timestamp()
        return dt.timestamp()

    # Ordenar por fecha descendente: el más nuevo primero (Puesto 1)
    all_active.sort(key=_get_ts, reverse=True)

    to_keep = all_active[:3]
    to_evict = all_active[3:]

    # Desalojar los que superen el límite de 3
    for old_c in to_evict:
        old_c.is_deleted = True
        old_c.updated_at = now

    # Re-etiquetar los hasta 3 contactos activos: Puesto 1 = Contacto 1, Puesto 2 = Contacto 2, Puesto 3 = Contacto 3
    for idx, c in enumerate(to_keep):
        c.label = f"Contacto {idx + 1}"
        c.is_primary = (idx == 0)
        c.updated_at = now

    db.flush()
    db.expire(person, ["contacts"])
    return to_keep


class PersonService:

    def create_person(
        self,
        db: Session,
        data: PersonCreate,
        current_user: User,
    ) -> Person:
        """
        Crea o actualiza una persona (UPSERT por número de documento).
        - Si ya existe un registro con el mismo document_number, actualiza los
          campos no nulos y fusiona los nuevos contactos manteniendo los anteriores.
        - Si es nuevo, crea el registro completo.
        """
        now = datetime.now(timezone.utc)

        # ── 1. Buscar duplicado por número de documento ────────────
        existing_by_doc = None
        if data.document_number and data.document_number.strip():
            existing_by_doc = (
                db.query(Person)
                .filter(
                    Person.document_number == data.document_number.strip(),
                    Person.is_deleted == False,
                )
                .first()
            )

        if existing_by_doc:
            # ── MODO ACTUALIZACIÓN ────────────────────────────────
            person = existing_by_doc

            # Actualizar campos solo si el nuevo valor no está vacío
            fields_to_update = [
                "first_name", "last_name", "document_type",
                "birth_date", "gender", "address", "city",
                "department", "country", "profession", "notes",
            ]
            for field in fields_to_update:
                new_val = getattr(data, field, None)
                if new_val is not None and new_val != "":
                    setattr(person, field, new_val)

            person.updated_at = now
            person.synced_at = now
            db.flush()

            # ── Aplicar regla de escalera a los contactos ─────────
            if data.contacts:
                _apply_contacts_escalera(
                    db=db,
                    person=person,
                    incoming_contacts=data.contacts,
                    now=now,
                    sync_source=data.sync_source,
                )

            db.flush()
            return person

        # ── 2. MODO CREACIÓN (persona nueva) ──────────────────────
        person_id = data.id or uuid4()

        # Verificar duplicado por UUID (puede venir de APK)
        existing_by_id = db.query(Person).filter(Person.id == person_id).first()
        if existing_by_id:
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
            profession=data.profession,
            notes=data.notes,
            captured_at=data.captured_at or now,
            synced_at=now,
            sync_source=data.sync_source,
            sync_status=SyncStatus.SYNCED,
        )
        db.add(person)
        db.flush()  # Para obtener el ID antes de asociar contactos

        # Crear contactos asociados aplicando la regla de escalera (máx 3)
        if data.contacts:
            _apply_contacts_escalera(
                db=db,
                person=person,
                incoming_contacts=data.contacts,
                now=now,
                sync_source=data.sync_source,
            )

        db.flush()
        return person

    def get_person(self, db: Session, person_id: UUID) -> Person:
        """Obtiene una persona con sus contactos activos (máximo 3). 404 si no existe."""
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
            if field == "contacts":
                continue
            # Aplicar regla de merge: no sobrescribir con vacío
            if value is not None and value != "":
                setattr(person, field, value)

        if data.contacts is not None:
            _apply_contacts_escalera(
                db=db,
                person=person,
                incoming_contacts=data.contacts,
                now=datetime.now(timezone.utc),
                sync_source=SyncSource.WEB,
            )

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
        """Agrega un contacto a una persona existente aplicando regla de escalera."""
        # Verificar que la persona existe
        person = self.get_person(db, data.person_id)

        now = datetime.now(timezone.utc)
        kept = _apply_contacts_escalera(
            db=db,
            person=person,
            incoming_contacts=[data],
            now=now,
            sync_source=data.sync_source,
        )
        person.updated_at = now
        db.flush()
        return kept[0] if kept else None


person_service = PersonService()
