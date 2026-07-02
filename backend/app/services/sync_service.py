"""
DataOff — Servicio de Sincronización
Orquesta el proceso completo de sincronización:
1. Recibe el payload de la APK
2. Invoca el MergeEngine
3. Persiste el SyncLog
4. Retorna el resultado
"""
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.enums import SyncLogStatus
from app.models.sync import SyncLog
from app.schemas.sync import SyncPushRequest, SyncPushResponse, SyncStatsResponse
from app.sync.merge_engine import merge_engine


class SyncService:

    def push_sync(
        self,
        db: Session,
        request: SyncPushRequest,
        user_id: Optional[UUID],
    ) -> SyncPushResponse:
        """
        Punto de entrada principal de la sincronización.
        Recibe registros de la APK y los procesa con el MergeEngine.
        """
        synced_at = datetime.now(timezone.utc)

        # Ejecutar el Merge Engine
        result = merge_engine.process(
            db=db,
            records=request.records,
            user_id=user_id,
            device_id=request.device_id,
        )

        # Determinar estado final
        failed_count = sum(1 for r in result.results if r.status == "failed")
        if failed_count == len(request.records):
            result.status = SyncLogStatus.FAILED
        elif failed_count > 0:
            result.status = SyncLogStatus.PARTIAL

        # Registrar en sync_logs
        sync_log = SyncLog(
            user_id=user_id,
            device_id=request.device_id,
            synced_at=synced_at,
            records_sent=len(request.records),
            records_inserted=result.inserted,
            records_updated=result.updated,
            records_skipped=result.skipped,
            conflicts_resolved=result.conflicts_resolved,
            status=result.status,
            detail={
                "records": [r.model_dump() for r in result.results],
                "client_timestamp": str(request.client_timestamp) if request.client_timestamp else None,
            },
        )
        db.add(sync_log)
        db.flush()

        return SyncPushResponse(
            sync_log_id=sync_log.id,
            synced_at=synced_at,
            records_sent=len(request.records),
            records_inserted=result.inserted,
            records_updated=result.updated,
            records_skipped=result.skipped,
            conflicts_resolved=result.conflicts_resolved,
            results=result.results,
            status=result.status,
        )

    def get_stats(self, db: Session) -> SyncStatsResponse:
        """Estadísticas globales del sistema de sincronización."""
        from sqlalchemy import func, distinct
        from app.models.sync import SyncLog


        total_syncs = db.query(func.count(SyncLog.id)).scalar() or 0
        successful = db.query(func.count(SyncLog.id)).filter(
            SyncLog.status == SyncLogStatus.SUCCESS
        ).scalar() or 0
        failed = db.query(func.count(SyncLog.id)).filter(
            SyncLog.status == SyncLogStatus.FAILED
        ).scalar() or 0
        total_records = db.query(func.sum(SyncLog.records_sent)).scalar() or 0
        total_conflicts = db.query(func.sum(SyncLog.conflicts_resolved)).scalar() or 0
        active_devices = db.query(func.count(distinct(SyncLog.device_id))).scalar() or 0
        last_sync = db.query(func.max(SyncLog.synced_at)).scalar()

        return SyncStatsResponse(
            total_syncs=total_syncs,
            successful_syncs=successful,
            failed_syncs=failed,
            total_records_synced=total_records,
            total_conflicts_resolved=total_conflicts,
            active_devices=active_devices,
            last_sync_at=last_sync,
        )


sync_service = SyncService()
