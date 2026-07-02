"""
DataOff — Registro central de modelos
Importa todos los modelos para que Alembic los detecte en las migraciones.
"""
from app.db.base_model import Base
from app.models.user import User
from app.models.person import Person, Contact
from app.models.sync import RefreshToken, SyncLog

__all__ = ["Base", "User", "Person", "Contact", "RefreshToken", "SyncLog"]
