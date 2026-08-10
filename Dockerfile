# =============================================================================
#  DataOff — Dockerfile (raíz del monorepo)
#  Multi-stage build:
#    Stage 1 (frontend-builder) : Compila React/Vite → dist/
#    Stage 2 (backend)          : FastAPI + archivos estáticos del frontend
#
#  Estructura del repo:
#    /backend   → FastAPI (Python 3.11)
#    /frontend  → React + Vite + TypeScript
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
#  STAGE 1 — Build del Frontend (Node)
# ─────────────────────────────────────────────────────────────────────────────
FROM node:20-alpine AS frontend-builder

WORKDIR /frontend

# Instalar dependencias primero (caché de Docker)
COPY frontend/package*.json ./
RUN npm ci --frozen-lockfile

# Copiar código fuente y compilar
COPY frontend/ .
RUN npm run build
# El resultado queda en /frontend/dist


# ─────────────────────────────────────────────────────────────────────────────
#  STAGE 2 — Backend FastAPI (Python)
# ─────────────────────────────────────────────────────────────────────────────
FROM python:3.11-slim AS backend

# ── Flags de Python ──────────────────────────────────────────────────────────
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONFAULTHANDLER=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# ── Dependencias de sistema ───────────────────────────────────────────────────
# libpq-dev       : cliente PostgreSQL (psycopg2)
# build-essential : compilar extensiones C (bcrypt, cryptography)
# libssl-dev      : dependencia de python-jose / cryptography
# curl            : healthchecks
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    libssl-dev \
    pkg-config \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# ── Usuario no-root (seguridad) ───────────────────────────────────────────────
RUN groupadd --gid 1001 appgroup \
    && useradd --uid 1001 --gid appgroup --shell /bin/bash --create-home appuser

# ── Directorio de trabajo ─────────────────────────────────────────────────────
WORKDIR /app

# ── Dependencias Python ───────────────────────────────────────────────────────
# Se copia solo requirements.txt primero → caché eficiente
COPY backend/requirements.txt .
RUN pip install --upgrade pip setuptools wheel \
    && pip install --no-cache-dir -r requirements.txt

# ── Código del backend ────────────────────────────────────────────────────────
COPY backend/ .

# ── Frontend compilado → servido como archivos estáticos ─────────────────────
# FastAPI puede servir el dist/ del frontend en producción
COPY --from=frontend-builder /frontend/dist ./static

# ── Permisos ──────────────────────────────────────────────────────────────────
RUN chown -R appuser:appgroup /app

USER appuser

# ── Puerto ────────────────────────────────────────────────────────────────────
EXPOSE 8000

# ── Healthcheck ───────────────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8000}/health || exit 1

# ── Arranque con Uvicorn ──────────────────────────────────────────────────────
CMD ["sh", "-c", \
    "uvicorn app.main:app \
        --host 0.0.0.0 \
        --port ${PORT:-8000} \
        --workers ${UVICORN_WORKERS:-2} \
        --log-level ${LOG_LEVEL:-info}"]
