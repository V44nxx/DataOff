"""
DataOff — Router de Reportes y Estadísticas del Dashboard
"""
from datetime import datetime, timezone, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, desc
from sqlalchemy.orm import Session

from app.core.dependencies import AdminUser, get_db
from app.models.person import Person, Contact
from app.models.sync import SyncLog
from app.models.user import User
from app.core.enums import SyncLogStatus

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/stats", summary="Estadísticas generales del dashboard")
def get_dashboard_stats(
    current_user: AdminUser,
    db: Session = Depends(get_db),
):
    """Retorna las estadísticas principales para el dashboard web."""
    now = datetime.now(timezone.utc)
    last_30_days = now - timedelta(days=30)
    last_7_days = now - timedelta(days=7)

    # Conteos generales
    total_persons = db.query(func.count(Person.id)).filter(Person.is_deleted == False).scalar() or 0
    total_contacts = db.query(func.count(Contact.id)).filter(Contact.is_deleted == False).scalar() or 0
    total_users = db.query(func.count(User.id)).filter(User.is_active == True).scalar() or 0
    total_syncs = db.query(func.count(SyncLog.id)).scalar() or 0

    # Últimos 30 días
    persons_last_30 = db.query(func.count(Person.id)).filter(
        Person.captured_at >= last_30_days,
        Person.is_deleted == False,
    ).scalar() or 0

    persons_last_7 = db.query(func.count(Person.id)).filter(
        Person.captured_at >= last_7_days,
        Person.is_deleted == False,
    ).scalar() or 0

    syncs_last_7 = db.query(func.count(SyncLog.id)).filter(
        SyncLog.synced_at >= last_7_days
    ).scalar() or 0

    # Personas por fuente (mobile vs web)
    from app.core.enums import SyncSource
    mobile_persons = db.query(func.count(Person.id)).filter(
        Person.sync_source == SyncSource.MOBILE,
        Person.is_deleted == False,
    ).scalar() or 0
    web_persons = total_persons - mobile_persons

    # Últimas sincronizaciones
    recent_syncs = db.query(SyncLog).order_by(desc(SyncLog.synced_at)).limit(5).all()

    return {
        "overview": {
            "total_persons": total_persons,
            "total_contacts": total_contacts,
            "total_users": total_users,
            "total_syncs": total_syncs,
        },
        "activity": {
            "persons_last_30_days": persons_last_30,
            "persons_last_7_days": persons_last_7,
            "syncs_last_7_days": syncs_last_7,
        },
        "sync_sources": {
            "mobile": mobile_persons,
            "web": web_persons,
        },
        "recent_syncs": [
            {
                "id": str(s.id),
                "device_id": s.device_id,
                "synced_at": s.synced_at.isoformat(),
                "records_sent": s.records_sent,
                "status": s.status.value,
            }
            for s in recent_syncs
        ],
    }


@router.get("/persons-by-city", summary="Personas agrupadas por ciudad")
def persons_by_city(
    current_user: AdminUser,
    db: Session = Depends(get_db),
    limit: int = Query(10, ge=1, le=50),
):
    """Top ciudades con más personas registradas."""
    results = (
        db.query(Person.city, func.count(Person.id).label("count"))
        .filter(Person.is_deleted == False, Person.city != None)
        .group_by(Person.city)
        .order_by(desc("count"))
        .limit(limit)
        .all()
    )
    return [{"city": r[0], "count": r[1]} for r in results]
