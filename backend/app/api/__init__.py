"""
DataOff — Registro central de routers de la API
"""
from fastapi import APIRouter
from app.api import auth, users, persons, sync, dashboard

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(persons.router)
api_router.include_router(sync.router)
api_router.include_router(dashboard.router)
