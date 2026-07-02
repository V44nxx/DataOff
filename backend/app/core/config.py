"""
DataOff Backend — Configuración Central
Usa Pydantic Settings para validar y tipear todas las variables de entorno.
"""
from functools import lru_cache
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import AnyHttpUrl, field_validator


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # ── Aplicación ─────────────────────────────────────────
    APP_NAME: str = "DataOff API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    ENVIRONMENT: str = "production"

    # ── Servidor ───────────────────────────────────────────
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # ── Base de Datos ──────────────────────────────────────
    DATABASE_URL: str
    ASYNC_DATABASE_URL: str

    # ── JWT ────────────────────────────────────────────────
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # ── CORS ───────────────────────────────────────────────
    ALLOWED_ORIGINS: str = "http://localhost:5173"

    @property
    def allowed_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",")]

    # ── Seguridad ──────────────────────────────────────────
    BCRYPT_ROUNDS: int = 12

    # ── Primer Superusuario ────────────────────────────────
    FIRST_SUPERUSER_EMAIL: str = "admin@dataoff.com"
    FIRST_SUPERUSER_PASSWORD: str = "Admin@DataOff2024"
    FIRST_SUPERUSER_NAME: str = "Administrador"


@lru_cache()
def get_settings() -> Settings:
    """Singleton de configuración — se carga una sola vez."""
    return Settings()


settings = get_settings()
