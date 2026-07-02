"""
DataOff — Router de Sincronización
El endpoint más importante: POST /sync/push
Lo usa la APK Flutter para sincronizar registros offline.
"""
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy import desc
from sqlalchemy.orm import Session

from app.core.dependencies import AdminUser, CurrentUser, get_db
from app.models.sync import SyncLog
from app.schemas.sync import (
    SyncLogResponse,
    SyncPushRequest,
    SyncPushResponse,
    SyncStatsResponse,
)
from app.services.sync_service import sync_service

router = APIRouter(prefix="/sync", tags=["Sincronización"])


@router.post(
    "/push",
    response_model=SyncPushResponse,
    summary="Sincronizar registros desde APK",
)
def push_sync(
    request: SyncPushRequest,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
):
    """
    **Endpoint principal de sincronización offline-first.**
    
    La APK Flutter envía todos sus registros pendientes en un solo request.
    El servidor ejecuta el Merge Engine para:
    
    1. Insertar registros nuevos (preservando `captured_at`)
    2. Actualizar registros existentes (campo a campo, sin sobrescribir vacíos)
    3. Resolver conflictos por reglas de negocio
    4. Retornar el resultado detallado por registro
    
    **Caso especial de sincronización tardía:**
    Un registro creado el 4-jun en la APK que llega en julio
    se insertará con `captured_at=4-jun`, apareciendo ANTES
    de un registro del 5-jun aunque llegó después.
    """
    return sync_service.push_sync(
        db=db,
        request=request,
        user_id=current_user.id,
    )


@router.get("/logs", response_model=List[SyncLogResponse], summary="Historial de sincronizaciones")
def get_sync_logs(
    current_user: AdminUser,
    db: Session = Depends(get_db),
    limit: int = Query(50, ge=1, le=500),
    device_id: Optional[str] = Query(None),
):
    """Lista el historial de sincronizaciones. Solo ADMIN+."""
    query = db.query(SyncLog).order_by(desc(SyncLog.synced_at))
    if device_id:
        query = query.filter(SyncLog.device_id == device_id)
    return query.limit(limit).all()


@router.get("/stats", response_model=SyncStatsResponse, summary="Estadísticas de sincronización")
def get_sync_stats(
    current_user: AdminUser,
    db: Session = Depends(get_db),
):
    """Estadísticas globales del sistema de sincronización."""
    return sync_service.get_stats(db=db)
