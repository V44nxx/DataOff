# DataOff — Scripts de Inicio Rápido (PowerShell)

# ── Paso 1: Backend ───────────────────────────────────────────
Write-Host "=== DataOff Backend ===" -ForegroundColor Cyan
Set-Location backend
if (-not (Test-Path "venv")) {
    python -m venv venv
}
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt --quiet
alembic upgrade head
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$PWD'; .\venv\Scripts\Activate.ps1; uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"

Set-Location ..

# ── Paso 2: Frontend ──────────────────────────────────────────
Write-Host "=== DataOff Frontend ===" -ForegroundColor Cyan
Set-Location frontend
if (-not (Test-Path "node_modules")) {
    npm install
}
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$PWD'; npm run dev"

Set-Location ..
Write-Host ""
Write-Host "DataOff iniciado:" -ForegroundColor Green
Write-Host "  Backend:  http://localhost:8000"   -ForegroundColor White
Write-Host "  API Docs: http://localhost:8000/docs" -ForegroundColor White
Write-Host "  Frontend: http://localhost:5173"   -ForegroundColor White
