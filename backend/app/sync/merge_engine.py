"""
DataOff — Merge Engine (Motor de Sincronización)
═══════════════════════════════════════════════════════════════════════════
Este es el componente más crítico del sistema.

ALGORITMO:
1. Para cada registro entrante, buscar por UUID en PostgreSQL.
2. Si NO existe → INSERT preservando captured_at original.
3. Si SÍ existe → comparar campo a campo:
   a. Nunca sobrescribir con null/""
   b. El campo con updated_at más reciente gana
   c. Registrar el conflicto en el log
4. Ordenamiento siempre por captured_at (no synced_at).

CASO ESPECIAL (latent sync):
- Registro creado el 4/jun en APK, sincronizado en julio.
- Ya existe registro del 5/jun creado desde la web.
- Resultado: ambos existen, ordenados por captured_at.
- El del 4/jun aparece PRIMERO aunque llegó después.

═══════════════════════════════════════════════════════════════════════════
"""
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.enums import (
    ContactType,
    SyncLogStatus,
    SyncOperation,
    SyncSource,
    SyncStatus,
)
from app.models.person import Contact, Person
from app.schemas.sync import SyncRecord, SyncRecordResult

logger = logging.getLogger(__name__)


class MergeResult:
    """Resultado acumulado del proceso de merge."""

    def __init__(self):
        self.inserted: int = 0
        self.updated: int = 0
        self.skipped: int = 0
        self.conflicts_resolved: int = 0
        self.results: List[SyncRecordResult] = []
        self.status: SyncLogStatus = SyncLogStatus.SUCCESS

    def add_result(self, result: SyncRecordResult):
        self.results.append(result)
        if result.status == "inserted":
            self.inserted += 1
        elif result.status == "updated":
            self.updated += 1
        elif result.status == "skipped":
            self.skipped += 1


# ════════════════════════════════════════════════════════════════
# REGLAS DE MERGE
# ════════════════════════════════════════════════════════════════

def _is_empty(value: Any) -> bool:
    """Determina si un valor es considerado 'vacío' para el merge."""
    if value is None:
        return True
    if isinstance(value, str) and value.strip() == "":
        return True
    return False


def _merge_fields(
    existing: Dict[str, Any],
    incoming: Dict[str, Any],
    existing_updated_at: datetime,
    incoming_updated_at: datetime,
) -> tuple[Dict[str, Any], int]:
    """
    Compara y fusiona dos diccionarios campo por campo.

    Reglas de prioridad:
    1. Si incoming es vacío → conservar existing.
    2. Si existing es vacío → usar incoming.
    3. Si ambos tienen valor → gana el más reciente (updated_at).

    Retorna: (campos_actualizados, número_de_conflictos_resueltos)
    """
    # Campos que NUNCA deben ser sobreescritos por el merge
    IMMUTABLE_FIELDS = {"id", "captured_at", "created_at", "sync_source"}

    # Campos que solo el servidor puede escribir
    SERVER_ONLY_FIELDS = {"synced_at", "sync_status"}

    updates: Dict[str, Any] = {}
    conflicts = 0

    for key, incoming_value in incoming.items():
        if key in IMMUTABLE_FIELDS or key in SERVER_ONLY_FIELDS:
            continue

        existing_value = existing.get(key)

        # Regla 1: incoming vacío → conservar existing
        if _is_empty(incoming_value):
            continue

        # Regla 2: existing vacío → usar incoming
        if _is_empty(existing_value):
            updates[key] = incoming_value
            continue

        # Regla 3: ambos tienen valor → comparar por timestamp
        if incoming_value != existing_value:
            conflicts += 1
            if incoming_updated_at > existing_updated_at:
                # El incoming es más reciente, pero necesitamos ser cuidadosos
                # Solo actualizamos si el incoming realmente es más nuevo
                logger.debug(
                    f"Conflicto en campo '{key}': "
                    f"existing='{existing_value}' (updated={existing_updated_at}) "
                    f"incoming='{incoming_value}' (updated={incoming_updated_at}) "
                    f"→ GANA incoming"
                )
                updates[key] = incoming_value
            else:
                logger.debug(
                    f"Conflicto en campo '{key}': "
                    f"existing='{existing_value}' gana sobre incoming='{incoming_value}'"
                )
                # El existing es más reciente o igual → no actualizar

    return updates, conflicts


# ════════════════════════════════════════════════════════════════
# PROCESADORES POR ENTIDAD
# ════════════════════════════════════════════════════════════════

def _process_person(
    db: Session,
    record: SyncRecord,
    user_id: Optional[UUID],
    device_id: str,
    synced_at: datetime,
    person_id_map: Optional[dict[UUID, UUID]] = None,
) -> SyncRecordResult:
    """Procesa un registro de tipo 'person' (insert o merge)."""
    data = record.data
    entity_id = data.get("id")

    if not entity_id:
        return SyncRecordResult(
            entity_type="person",
            entity_id="unknown",
            operation=record.operation,
            status="failed",
            message="Campo 'id' ausente en el registro",
        )

    try:
        uuid_id = UUID(str(entity_id))
    except ValueError:
        return SyncRecordResult(
            entity_type="person",
            entity_id=str(entity_id),
            operation=record.operation,
            status="failed",
            message=f"UUID inválido: {entity_id}",
        )

    # ── Buscar registro existente ──────────────────────────
    # 1. Buscar por UUID (caso normal: ya se sincronizó antes)
    existing_person = db.query(Person).filter(Person.id == uuid_id).first()

    # 2. Fallback: buscar por número de documento para evitar duplicados
    #    (ocurre cuando la APK crea la persona offline con un UUID diferente
    #     al que ya está guardado en la web con el mismo documento)
    if existing_person is None:
        doc_number = data.get("document_number")
        if doc_number and str(doc_number).strip():
            existing_person = (
                db.query(Person)
                .filter(
                    Person.document_number == str(doc_number).strip(),
                    Person.is_deleted == False,
                )
                .first()
            )
            if existing_person:
                logger.info(
                    f"Person {uuid_id} no encontrada por UUID, pero sí por "
                    f"document_number='{doc_number}' → se fusionará en lugar de insertar"
                )

    if person_id_map is not None:
        target_parent_id = existing_person.id if existing_person else uuid_id
        person_id_map[uuid_id] = target_parent_id
        person_id_map[str(uuid_id)] = target_parent_id
        person_id_map[str(uuid_id).lower()] = target_parent_id

    if record.operation == SyncOperation.DELETE:
        if existing_person:
            existing_person.is_deleted = True
            existing_person.deleted_at = synced_at
            existing_person.updated_at = synced_at
            return SyncRecordResult(
                entity_type="person",
                entity_id=str(uuid_id),
                operation=record.operation,
                status="updated",
                message="Soft delete aplicado",
            )
        return SyncRecordResult(
            entity_type="person",
            entity_id=str(uuid_id),
            operation=record.operation,
            status="skipped",
            message="Registro no encontrado para eliminar",
        )

    if existing_person is None:
        # ── INSERT: Registro nuevo ─────────────────────────
        captured_at_raw = data.get("captured_at")
        if captured_at_raw:
            if isinstance(captured_at_raw, str):
                captured_at = datetime.fromisoformat(captured_at_raw.replace("Z", "+00:00"))
            else:
                captured_at = captured_at_raw
        else:
            captured_at = synced_at

        new_person = Person(
            id=uuid_id,
            user_id=user_id,
            first_name=data.get("first_name", ""),
            last_name=data.get("last_name", ""),
            document_type=data.get("document_type"),
            document_number=data.get("document_number"),
            birth_date=_parse_datetime(data.get("birth_date")),
            gender=data.get("gender"),
            address=data.get("address"),
            city=data.get("city"),
            department=data.get("department"),
            country=data.get("country", "Colombia"),
            profession=data.get("profession"),
            notes=data.get("notes"),
            captured_at=captured_at,       # ← INMUTABLE: fecha real de captura
            synced_at=synced_at,           # ← Asignado por el servidor
            sync_source=SyncSource.MOBILE,
            sync_status=SyncStatus.SYNCED,
            device_id=device_id,
        )
        db.add(new_person)
        db.flush()
        logger.info(f"Person insertada: {uuid_id} (captured_at={captured_at})")

        return SyncRecordResult(
            entity_type="person",
            entity_id=str(uuid_id),
            operation=record.operation,
            status="inserted",
            message=f"Insertada con captured_at={captured_at}",
        )

    else:
        # ── UPDATE: Aplicar merge ──────────────────────────
        incoming_updated_at = _parse_datetime(data.get("updated_at")) or synced_at
        existing_updated_at = existing_person.updated_at

        existing_dict = {
            "first_name": existing_person.first_name,
            "last_name": existing_person.last_name,
            "document_type": existing_person.document_type,
            "document_number": existing_person.document_number,
            "address": existing_person.address,
            "city": existing_person.city,
            "department": existing_person.department,
            "country": existing_person.country,
            "profession": existing_person.profession,
            "notes": existing_person.notes,
            "gender": existing_person.gender,
        }

        updates, conflicts = _merge_fields(
            existing_dict,
            data,
            existing_updated_at=existing_updated_at,
            incoming_updated_at=incoming_updated_at,
        )

        if updates:
            for field, value in updates.items():
                if hasattr(existing_person, field):
                    setattr(existing_person, field, value)
            existing_person.updated_at = max(existing_updated_at, incoming_updated_at)
            existing_person.synced_at = synced_at
            db.flush()

            action_msg = f"{len(updates)} campo(s) actualizados, {conflicts} conflicto(s) resueltos"
            logger.info(f"Person actualizada: {uuid_id} — {action_msg}")

            return SyncRecordResult(
                entity_type="person",
                entity_id=str(uuid_id),
                operation=record.operation,
                status="updated",
                message=action_msg,
            )
        else:
            logger.debug(f"Person sin cambios: {uuid_id}")
            return SyncRecordResult(
                entity_type="person",
                entity_id=str(uuid_id),
                operation=record.operation,
                status="skipped",
                message="Sin cambios detectados",
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


def _process_contact(
    db: Session,
    record: SyncRecord,
    device_id: str,
    synced_at: datetime,
    person_id_map: Optional[dict[UUID, UUID]] = None,
) -> SyncRecordResult:
    """Procesa un registro de tipo 'contact'."""
    data = record.data
    entity_id = data.get("id")

    if not entity_id:
        return SyncRecordResult(
            entity_type="contact",
            entity_id="unknown",
            operation=record.operation,
            status="failed",
            message="Campo 'id' ausente",
        )

    try:
        uuid_id = UUID(str(entity_id))
        person_uuid = UUID(str(data.get("person_id")))
    except (ValueError, TypeError) as e:
        return SyncRecordResult(
            entity_type="contact",
            entity_id=str(entity_id),
            operation=record.operation,
            status="failed",
            message=f"UUID inválido: {e}",
        )

    # Remapear person_uuid si la persona padre fue fusionada por documento
    if person_id_map:
        original_parent = person_uuid
        if person_uuid in person_id_map:
            person_uuid = person_id_map[person_uuid]
        elif str(person_uuid) in person_id_map:
            person_uuid = person_id_map[str(person_uuid)]
        elif str(person_uuid).lower() in person_id_map:
            person_uuid = person_id_map[str(person_uuid).lower()]

        if original_parent != person_uuid:
            logger.info(
                f"Contact {uuid_id}: person_id remapeado de {original_parent} a "
                f"{person_uuid} (fusión por documento)"
            )

    # Verificar que la persona padre existe
    parent_person = db.query(Person).filter(Person.id == person_uuid).first()
    if not parent_person:
        return SyncRecordResult(
            entity_type="contact",
            entity_id=str(uuid_id),
            operation=record.operation,
            status="failed",
            message=f"Persona padre {person_uuid} no encontrada",
        )

    contact_val = str(data.get("contact_value", "")).strip()

    # 1. Buscar contacto existente por UUID
    existing_contact = db.query(Contact).filter(Contact.id == uuid_id).first()

    # 2. Si no existe por UUID, verificar si la persona ya tiene un contacto activo con el mismo valor
    if existing_contact is None and contact_val:
        existing_contact = (
            db.query(Contact)
            .filter(
                Contact.person_id == person_uuid,
                Contact.contact_value == contact_val,
                Contact.is_deleted == False,
            )
            .first()
        )

    if record.operation == SyncOperation.DELETE:
        if existing_contact:
            existing_contact.is_deleted = True
            existing_contact.updated_at = synced_at
            db.flush()
            return SyncRecordResult(
                entity_type="contact",
                entity_id=str(uuid_id),
                operation=record.operation,
                status="updated",
                message="Soft delete aplicado",
            )
        return SyncRecordResult(
            entity_type="contact",
            entity_id=str(uuid_id),
            operation=record.operation,
            status="skipped",
            message="Contacto no encontrado para eliminar",
        )

    captured_at_raw = data.get("captured_at")
    captured_at = _parse_datetime(captured_at_raw) or synced_at

    # Obtener contactos activos actuales de la persona
    active_contacts = (
        db.query(Contact)
        .filter(
            Contact.person_id == person_uuid,
            Contact.is_deleted == False,
        )
        .all()
    )

    contact_record_status = "inserted"
    if existing_contact is not None:
        if existing_contact.is_deleted:
            # Reactivar contacto previo
            existing_contact.is_deleted = False
            existing_contact.captured_at = captured_at
            existing_contact.updated_at = synced_at
            existing_contact.synced_at = synced_at
            current_target_contact = existing_contact
            contact_record_status = "updated"
        else:
            # Ya existe activo
            existing_contact.synced_at = synced_at
            current_target_contact = existing_contact
            contact_record_status = "skipped"
    else:
        new_contact = Contact(
            id=uuid_id,
            person_id=person_uuid,
            contact_type=_normalize_contact_type(data.get("contact_type")),
            contact_value=contact_val,
            is_primary=data.get("is_primary", False),
            label=data.get("label"),
            captured_at=captured_at,
            synced_at=synced_at,
            sync_source=SyncSource.MOBILE,
        )
        db.add(new_contact)
        current_target_contact = new_contact
        contact_record_status = "inserted"

    parent_person.updated_at = synced_at
    parent_person.synced_at = synced_at

    # ── Regla de Escalera: Máximo 3 contactos activos por persona ──
    # Unir contactos activos y ordenar por fecha descendente (más nuevo en Puesto 1)
    all_active = [c for c in active_contacts if c.id != current_target_contact.id and not c.is_deleted]
    all_active.append(current_target_contact)

    def _contact_sort_ts(ct: Contact) -> float:
        dt = ct.captured_at or ct.created_at or synced_at
        if dt is None:
            return 0.0
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc).timestamp()
        return dt.timestamp()

    all_active.sort(key=_contact_sort_ts, reverse=True)

    to_keep = all_active[:3]
    to_evict = all_active[3:]

    # Desalojar los que superen el límite de 3
    for ev in to_evict:
        ev.is_deleted = True
        ev.updated_at = synced_at
        logger.info(
            f"Escalera max 3 contactos: se desactiva contacto antiguo {ev.contact_value} "
            f"de persona {person_uuid}"
        )

    # Re-etiquetar los hasta 3 contactos activos
    for idx, c in enumerate(to_keep):
        c.label = f"Contacto {idx + 1}"
        c.is_primary = (idx == 0)
        c.updated_at = synced_at

    db.flush()

    action_msg = "Contacto insertado/escalera" if contact_record_status == "inserted" else (
        "Contacto reactivado/escalera" if contact_record_status == "updated" else "Contacto ya existe para esta persona"
    )

    return SyncRecordResult(
        entity_type="contact",
        entity_id=str(uuid_id),
        operation=record.operation,
        status=contact_record_status,
        message=f"{action_msg} ({contact_val})",
    )


# ════════════════════════════════════════════════════════════════
# MERGE ENGINE PRINCIPAL
# ════════════════════════════════════════════════════════════════

class MergeEngine:
    """
    Motor de sincronización principal.
    Orquesta el procesamiento de todos los registros entrantes.
    """

    def process(
        self,
        db: Session,
        records: List[SyncRecord],
        user_id: Optional[UUID],
        device_id: str,
    ) -> MergeResult:
        """
        Procesa una lista de registros de sincronización.
        
        El procesamiento se hace en dos pasadas:
        1. Personas primero (para que los contactos puedan referenciarlas)
        2. Contactos después
        
        Usa una sola transacción — si algo falla, se hace rollback completo.
        """
        synced_at = datetime.now(timezone.utc)
        result = MergeResult()

        # Separar por entidad para procesar en el orden correcto
        person_records = [r for r in records if r.entity_type == "person"]
        contact_records = [r for r in records if r.entity_type == "contact"]
        unknown_records = [r for r in records if r.entity_type not in ("person", "contact")]

        logger.info(
            f"MergeEngine: procesando {len(records)} registros "
            f"({len(person_records)} personas, {len(contact_records)} contactos)"
        )

        person_id_map: dict[UUID, UUID] = {}

        # ── Pasada 1: Personas ─────────────────────────────
        for record in person_records:
            try:
                record_result = _process_person(db, record, user_id, device_id, synced_at, person_id_map)
            except Exception as e:
                logger.exception(f"Error procesando person {record.data.get('id')}: {e}")
                record_result = SyncRecordResult(
                    entity_type="person",
                    entity_id=str(record.data.get("id", "unknown")),
                    operation=record.operation,
                    status="failed",
                    message=str(e),
                )
                result.status = SyncLogStatus.PARTIAL

            if record_result.status in ("updated",) and "conflicto" in (record_result.message or "").lower():
                result.conflicts_resolved += 1

            result.add_result(record_result)

        # Forzar flush de todas las personas creadas/modificadas antes de procesar contactos
        db.flush()

        # ── Pasada 2: Contactos ────────────────────────────
        for record in contact_records:
            try:
                record_result = _process_contact(db, record, device_id, synced_at, person_id_map)
            except Exception as e:
                logger.exception(f"Error procesando contact {record.data.get('id')}: {e}")
                record_result = SyncRecordResult(
                    entity_type="contact",
                    entity_id=str(record.data.get("id", "unknown")),
                    operation=record.operation,
                    status="failed",
                    message=str(e),
                )
                result.status = SyncLogStatus.PARTIAL

            result.add_result(record_result)

        # ── Registros de entidad desconocida ───────────────
        for record in unknown_records:
            result.add_result(SyncRecordResult(
                entity_type=record.entity_type,
                entity_id=str(record.data.get("id", "unknown")),
                operation=record.operation,
                status="failed",
                message=f"Entidad desconocida: '{record.entity_type}'",
            ))
            result.status = SyncLogStatus.PARTIAL

        logger.info(
            f"MergeEngine completado: "
            f"inserted={result.inserted}, updated={result.updated}, "
            f"skipped={result.skipped}, conflicts={result.conflicts_resolved}"
        )

        return result


# ── Utilidades ─────────────────────────────────────────────────
def _parse_datetime(value: Any) -> Optional[datetime]:
    """Parsea una fecha de distintos formatos de forma segura."""
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    if isinstance(value, str):
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return None
    return None


# ── Instancia singleton ────────────────────────────────────────
merge_engine = MergeEngine()
