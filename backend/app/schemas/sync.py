"""
DataOff — Schemas de Sincronización
Define el contrato de la API de sincronización que usa la APK Flutter.
"""
from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, Field

from app.core.enums import SyncLogStatus, SyncOperation, SyncSource, SyncStatus


# ════════════════════════════════════════════════════════════════
# PAYLOAD DE SINCRONIZACIÓN (APK → Servidor)
# ════════════════════════════════════════════════════════════════

class SyncRecord(BaseModel):
    """Un registro individual en la cola de sincronización."""
    entity_type: str = Field(..., description="'person' | 'contact'")
    operation: SyncOperation
    data: Dict[str, Any] = Field(..., description="Datos completos del registro")
    local_id: Optional[str] = None     # ID local en SQLite (para debugging)


class SyncPushRequest(BaseModel):
    """
    Payload que envía la APK al servidor.
    Contiene todos los registros pendientes de sincronización.
    """
    device_id: str = Field(..., min_length=1, max_length=255)
    records: List[SyncRecord] = Field(..., min_length=1)
    client_timestamp: Optional[datetime] = None   # Timestamp del dispositivo


# ════════════════════════════════════════════════════════════════
# RESPUESTA DE SINCRONIZACIÓN (Servidor → APK)
# ════════════════════════════════════════════════════════════════

class SyncRecordResult(BaseModel):
    """Resultado del procesamiento de un registro individual."""
    entity_type: str
    entity_id: str                    # UUID del registro procesado
    operation: SyncOperation
    status: str                        # 'inserted' | 'updated' | 'skipped' | 'failed'
    message: Optional[str] = None


class SyncPushResponse(BaseModel):
    """Respuesta completa al push de sincronización."""
    sync_log_id: UUID
    synced_at: datetime
    records_sent: int
    records_inserted: int
    records_updated: int
    records_skipped: int
    conflicts_resolved: int
    results: List[SyncRecordResult]
    status: SyncLogStatus


# ════════════════════════════════════════════════════════════════
# SYNC LOGS (para el dashboard web)
# ════════════════════════════════════════════════════════════════

class SyncLogResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: UUID
    user_id: Optional[UUID] = None
    device_id: Optional[str] = None
    synced_at: datetime
    records_sent: int
    records_inserted: int
    records_updated: int
    records_skipped: int
    conflicts_resolved: int
    status: SyncLogStatus
    error_message: Optional[str] = None


class SyncStatsResponse(BaseModel):
    """Estadísticas globales del sistema de sincronización."""
    total_syncs: int
    successful_syncs: int
    failed_syncs: int
    total_records_synced: int
    total_conflicts_resolved: int
    active_devices: int
    last_sync_at: Optional[datetime] = None
