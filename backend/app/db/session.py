"""
DataOff — Sesión de Base de Datos
Configura el engine de SQLAlchemy y provee la dependencia get_db para FastAPI.
"""
from typing import Generator

from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings

# ── Engine síncrono (para uso con FastAPI sync endpoints) ──────────────────
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,           # Verifica conexión antes de usar del pool
    pool_size=10,                  # Conexiones simultáneas
    max_overflow=20,               # Conexiones adicionales en picos
    echo=settings.DEBUG,           # Imprime SQL en modo debug
)

# ── Session Factory ────────────────────────────────────────────────────────
SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
    expire_on_commit=False,        # Evita lazy loading después de commit
)


def get_db() -> Generator[Session, None, None]:
    """
    Dependencia de FastAPI para inyección de sesión de base de datos.
    Garantiza que la sesión se cierre correctamente al terminar el request.
    
    Uso:
        @router.get("/items")
        def get_items(db: Session = Depends(get_db)):
            ...
    """
    db = SessionLocal()
    try:
        yield db
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()
