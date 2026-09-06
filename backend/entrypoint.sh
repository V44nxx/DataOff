#!/bin/sh
set -e

echo "========================================="
echo "🚀 Iniciando DataOff Backend..."
echo "========================================="

# 1. Ejecutar migraciones con Alembic
echo "==> [1/3] Aplicando migraciones de base de datos..."
alembic upgrade head

# 2. Inicializar superusuario si no existe
echo "==> [2/3] Verificando / Inicializando superusuario..."
python -m app.db.init_db || echo "Advertencia: No se pudo ejecutar el seeder inicial."

# 3. Arrancar Uvicorn
echo "==> [3/3] Arrancando servidor Uvicorn en puerto ${PORT:-8000}..."
exec uvicorn app.main:app \
    --host 0.0.0.0 \
    --port "${PORT:-8000}" \
    --workers "${UVICORN_WORKERS:-2}" \
    --log-level "${LOG_LEVEL:-info}"
