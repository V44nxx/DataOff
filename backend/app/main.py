"""
DataOff — Punto de Entrada Principal (FastAPI)
Configura la aplicación, middlewares, CORS y arranque.
"""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api import api_router
from app.core.config import settings
from app.db.session import SessionLocal

# ── Configuración del logger ───────────────────────────────────
logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)


# ── Ciclo de vida de la aplicación ────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Ejecuta tareas de inicialización al arrancar el servidor.
    El bloque antes de 'yield' es startup; después de 'yield' es shutdown.
    """
    logger.info(f"🚀 Iniciando {settings.APP_NAME} v{settings.APP_VERSION}")
    logger.info(f"   Entorno: {settings.ENVIRONMENT}")

    # Inicializar DB (crear superusuario si no existe)
    if settings.ENVIRONMENT in ("development", "staging"):
        from app.db.init_db import init_db
        db = SessionLocal()
        try:
            init_db(db)
        finally:
            db.close()

    yield

    logger.info("🛑 Cerrando DataOff API")


# ── Instancia de FastAPI ───────────────────────────────────────
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="""
## DataOff — Sistema Offline-First Empresarial

API REST para la captura y sincronización de datos en entornos con conectividad intermitente.

### Características principales
- ✅ Sincronización offline-first
- ✅ Motor de merge con resolución de conflictos
- ✅ Preservación de `captured_at` como fuente de verdad temporal
- ✅ Autenticación JWT con rotación de tokens
- ✅ Control de acceso basado en roles (RBAC)
    """,
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
    lifespan=lifespan,
)


# ── Middlewares ────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Manejadores de errores globales ───────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.exception(f"Error no manejado en {request.method} {request.url}: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "Error interno del servidor",
            "path": str(request.url),
        },
    )


# ── Routers ────────────────────────────────────────────────────
app.include_router(api_router)


# ── Health check ──────────────────────────────────────────────
@app.get("/health", tags=["Sistema"], summary="Estado del servidor")
def health_check():
    """Verifica que el servidor está funcionando correctamente."""
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "environment": settings.ENVIRONMENT,
    }


@app.get("/", tags=["Sistema"])
def root():
    return {
        "message": f"Bienvenido a {settings.APP_NAME}",
        "docs": "/docs",
        "version": settings.APP_VERSION,
    }


# ── Arranque directo ───────────────────────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG,
        log_level="debug" if settings.DEBUG else "info",
    )
