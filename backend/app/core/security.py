"""
DataOff — Seguridad: Hash de contraseñas y JWT
Centraliza toda la lógica de seguridad del sistema.
"""
from datetime import datetime, timedelta, timezone
from typing import Any, Optional
from uuid import UUID

from jose import JWTError, jwt
import bcrypt

from app.core.config import settings
from app.core.enums import UserRole

def hash_password(plain_password: str) -> str:
    """Hashea una contraseña usando bcrypt."""
    salt = bcrypt.gensalt(rounds=settings.BCRYPT_ROUNDS)
    hashed_bytes = bcrypt.hashpw(plain_password.encode('utf-8'), salt)
    return hashed_bytes.decode('utf-8')


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verifica una contraseña contra su hash."""
    try:
        return bcrypt.checkpw(
            plain_password.encode('utf-8'), 
            hashed_password.encode('utf-8')
        )
    except ValueError:
        return False


# ── JWT ────────────────────────────────────────────────────────────────────
def create_access_token(
    subject: str | UUID,
    role: UserRole,
    extra_claims: Optional[dict] = None,
) -> str:
    """
    Crea un JWT de acceso.
    - subject: user_id (UUID como str)
    - role: rol del usuario para autorización
    - extra_claims: datos adicionales opcionales en el payload
    """
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload: dict[str, Any] = {
        "sub": str(subject),
        "role": role.value if isinstance(role, UserRole) else role,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "type": "access",
    }
    if extra_claims:
        payload.update(extra_claims)

    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_refresh_token(subject: str | UUID) -> tuple[str, datetime]:
    """
    Crea un JWT de refresco.
    Retorna (token, fecha_de_expiración).
    """
    expire = datetime.now(timezone.utc) + timedelta(
        days=settings.REFRESH_TOKEN_EXPIRE_DAYS
    )
    payload: dict[str, Any] = {
        "sub": str(subject),
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "type": "refresh",
    }
    token = jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
    return token, expire


def decode_token(token: str) -> dict[str, Any]:
    """
    Decodifica y valida un JWT.
    Lanza JWTError si es inválido o expirado.
    """
    return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])


# ── Permisos por Rol ───────────────────────────────────────────────────────
ROLE_HIERARCHY = {
    UserRole.SUPER_ADMIN: 4,
    UserRole.ADMIN: 3,
    UserRole.ASESOR: 2,
    UserRole.AUDITOR: 1,
}


def has_permission(user_role: UserRole, required_role: UserRole) -> bool:
    """
    Retorna True si user_role tiene al menos el nivel de required_role.
    Ejemplo: has_permission(ADMIN, ASESOR) → True
    """
    return ROLE_HIERARCHY.get(user_role, 0) >= ROLE_HIERARCHY.get(required_role, 0)
