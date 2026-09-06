"""
DataOff — Punto de Entrada Principal (FastAPI)
Configura la aplicación, middlewares, CORS y arranque.
"""

import logging
import mimetypes
from contextlib import asynccontextmanager
from pathlib import Path

# Registrar MIME type de APK para que Android lo reconozca como instalador nativo y no como ZIP
mimetypes.add_type("application/vnd.android.package-archive", ".apk")

from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles

from app.api import api_router
from app.core.config import settings
from app.db.session import SessionLocal


# ── Configuración del logger ───────────────────────────────────

logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s | %(levelname)-8s | %(name)s | %(message)s",
)

logger = logging.getLogger(__name__)


# ── Ciclo de vida de la aplicación ─────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Ejecuta tareas de inicialización al arrancar el servidor.
    El bloque antes de 'yield' es startup; después de 'yield' es shutdown.
    """

    logger.info(
        f"🚀 Iniciando {settings.APP_NAME} v{settings.APP_VERSION}"
    )

    logger.info(
        f"   Entorno: {settings.ENVIRONMENT}"
    )

    # Inicializar DB
    # Crear superusuario si no existe solamente en development/staging
    if settings.ENVIRONMENT in ("development", "staging"):
        from app.db.init_db import init_db

        db = SessionLocal()

        try:
            init_db(db)
        finally:
            db.close()

    yield

    logger.info("🛑 Cerrando DataOff API")


# ── Ubicación del frontend ─────────────────────────────────────

# Estructura dentro del contenedor:
#
# /app
# ├── app/
# │   ├── main.py
# │   └── ...
# │
# └── static/
#     ├── index.html
#     └── assets/
#
# Docker copia:
# frontend/dist → /app/static

BASE_DIR = Path(__file__).resolve().parent.parent
STATIC_DIR = BASE_DIR / "static"


# ── Instancia de FastAPI ───────────────────────────────────────

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="""

## DataOff — Sistema Offline-First Empresarial

API REST para la captura y sincronización de datos en entornos con
conectividad intermitente.

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


# ── Manejadores de errores globales ────────────────────────────

@app.exception_handler(Exception)
async def global_exception_handler(
    request: Request,
    exc: Exception
):
    logger.exception(
        f"Error no manejado en {request.method} {request.url}: {exc}"
    )

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "Error interno del servidor",
            "path": str(request.url),
        },
    )


# ── Routers de la API ──────────────────────────────────────────

app.include_router(api_router)


# ── Archivos estáticos del frontend ────────────────────────────

# Sirve:
#
# /assets/index-xxxxx.js
# /assets/index-xxxxx.css
# /assets/...
#
# desde:
#
# /app/static/assets/

if (STATIC_DIR / "assets").exists():
    app.mount(
        "/assets",
        StaticFiles(directory=STATIC_DIR / "assets"),
        name="assets",
    )


# ── Health check ───────────────────────────────────────────────

@app.get(
    "/health",
    tags=["Sistema"],
    summary="Estado del servidor",
)
def health_check():
    """
    Verifica que el servidor está funcionando correctamente.
    """

    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "environment": settings.ENVIRONMENT,
    }


# ── Frontend React ─────────────────────────────────────────────

@app.get(
    "/",
    include_in_schema=False,
)
async def root():
    """
    Sirve la aplicación React si existe el build estático.
    De lo contrario, devuelve el estado de la API.
    """
    index_path = STATIC_DIR / "index.html"
    if index_path.is_file():
        return FileResponse(index_path)

    return {
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "online",
        "docs": "/docs" if settings.DEBUG else None,
    }


# ── Descarga de APK para Android ───────────────────────────────

@app.get(
    "/DataOff.apk",
    include_in_schema=False,
)
@app.get(
    "/download/apk",
    include_in_schema=False,
)
@app.get(
    "/api/v1/download/apk",
    tags=["Descargas"],
    summary="Descargar APK de Android",
)
async def download_apk():
    """
    Descarga directa del paquete instalador de Android (APK).
    Configura el MIME type oficial `application/vnd.android.package-archive`
    y cabeceras `Content-Disposition: attachment` para evitar que los navegadores
    móviles (Google Chrome, Samsung Internet) guarden el archivo como .zip.
    """
    apk_path = STATIC_DIR / "DataOff.apk"
    if not apk_path.is_file():
        return JSONResponse(
            status_code=status.HTTP_404_NOT_FOUND,
            content={"detail": "Archivo APK no encontrado en el servidor."},
        )

    return FileResponse(
        path=apk_path,
        filename="DataOff.apk",
        media_type="application/vnd.android.package-archive",
        headers={
            "Content-Type": "application/vnd.android.package-archive",
            "Content-Disposition": 'attachment; filename="DataOff.apk"',
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache",
            "Expires": "0",
        },
    )


# ── React Router / Fallback ────────────────────────────────────

@app.get(
    "/{full_path:path}",
    include_in_schema=False,
)
async def serve_frontend(full_path: str):
    """
    Permite que React Router maneje las rutas del frontend si los archivos existen.
    Si no existe frontend compilado, responde 404 limpio.
    """
    file_path = STATIC_DIR / full_path

    if file_path.is_file():
        if file_path.suffix.lower() == ".apk":
            return FileResponse(
                path=file_path,
                filename=file_path.name,
                media_type="application/vnd.android.package-archive",
                headers={
                    "Content-Type": "application/vnd.android.package-archive",
                    "Content-Disposition": f'attachment; filename="{file_path.name}"',
                    "Cache-Control": "no-cache, no-store, must-revalidate",
                },
            )
        return FileResponse(file_path)

    index_path = STATIC_DIR / "index.html"
    if index_path.is_file():
        return FileResponse(index_path)

    return JSONResponse(
        status_code=status.HTTP_404_NOT_FOUND,
        content={
            "detail": "Ruta no encontrada",
            "path": f"/{full_path}",
        },
    )


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