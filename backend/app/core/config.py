"""
DataOff Backend — Configuración Central
Usa Pydantic Settings para validar y tipear todas las variables de entorno.
"""
from functools import lru_cache
from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import AnyHttpUrl, field_validator


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
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
    DATABASE_URL: str = "postgresql://dataoff_user:dataoff_password@localhost:5432/dataoff_db"
    ASYNC_DATABASE_URL: Optional[str] = None

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def validate_database_url(cls, v):
        if not v or not str(v).strip():
            return "postgresql://dataoff_user:dataoff_password@localhost:5432/dataoff_db"
        return str(v).strip()

    # ── JWT ────────────────────────────────────────────────
    SECRET_KEY: str = "dataoff-default-secret-key-change-in-production-min-32-chars"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    @field_validator("SECRET_KEY", mode="before")
    @classmethod
    def validate_secret_key(cls, v):
        if not v or not str(v).strip():
            return "dataoff-default-secret-key-change-in-production-min-32-chars"
        return str(v).strip()

    # ── CORS ───────────────────────────────────────────────
    ALLOWED_ORIGINS: str = "*"

    @property
    def allowed_origins_list(self) -> List[str]:
        if not self.ALLOWED_ORIGINS or self.ALLOWED_ORIGINS.strip() == "*":
            return ["*"]
        return [origin.strip() for origin in self.ALLOWED_ORIGINS.split(",") if origin.strip()]

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
