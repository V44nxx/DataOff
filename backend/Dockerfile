# =============================================================================
#  DataOff — Backend Dockerfile (para Dokploy / Docker)
# =============================================================================
FROM python:3.11-slim

# Flags de Python para rendimiento y logs en tiempo real
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Dependencias del sistema (cliente PostgreSQL, compilador y curl para healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Crear usuario no-root por seguridad
RUN groupadd --gid 1001 appgroup \
    && useradd --uid 1001 --gid appgroup --shell /bin/bash --create-home appuser

WORKDIR /app

# Instalar dependencias de Python (aprovechando caché de Docker)
COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r requirements.txt

# Copiar el código del backend
COPY --chown=appuser:appgroup . .

# Permisos de ejecución para el script de inicio
RUN chmod +x /app/entrypoint.sh

# Cambiar a usuario no-root
USER appuser

# Puerto interno del contenedor
EXPOSE 8000

# Healthcheck que consulta el endpoint /health de FastAPI
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8000}/health || exit 1

# Script de arranque (migraciones + superusuario + uvicorn)
ENTRYPOINT ["/app/entrypoint.sh"]
