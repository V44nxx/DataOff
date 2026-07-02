"""
DataOff — Inicialización de la Base de Datos
Crea el superusuario inicial si no existe.
"""
import logging
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.enums import UserRole
from app.core.security import hash_password
from app.models.user import User

logger = logging.getLogger(__name__)


def init_db(db: Session) -> None:
    """
    Inicializa la base de datos con datos esenciales.
    Se ejecuta al arrancar el servidor en modo desarrollo.
    Idempotente: seguro de ejecutar múltiples veces.
    """
    _create_superuser(db)


def _create_superuser(db: Session) -> None:
    """Crea el superusuario inicial si no existe."""
    existing = db.query(User).filter(
        User.email == settings.FIRST_SUPERUSER_EMAIL.lower()
    ).first()

    if existing:
        logger.info(f"Superusuario ya existe: {settings.FIRST_SUPERUSER_EMAIL}")
        return

    superuser = User(
        email=settings.FIRST_SUPERUSER_EMAIL.lower(),
        hashed_password=hash_password(settings.FIRST_SUPERUSER_PASSWORD),
        full_name=settings.FIRST_SUPERUSER_NAME,
        role=UserRole.SUPER_ADMIN,
        is_active=True,
    )
    db.add(superuser)
    db.commit()
    logger.info(
        f"✅ Superusuario creado: {settings.FIRST_SUPERUSER_EMAIL} "
        f"(rol: {UserRole.SUPER_ADMIN.value})"
    )
