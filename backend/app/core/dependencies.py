"""
DataOff — Dependencias de FastAPI
Inyección de dependencias para autenticación y autorización.
"""
from typing import Annotated
from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy.orm import Session

from app.core.enums import UserRole
from app.core.security import decode_token, has_permission
from app.db.session import get_db
from app.models.user import User

# ── Esquema de autenticación Bearer ───────────────────────────────────────
bearer_scheme = HTTPBearer(auto_error=True)


def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    """
    Dependencia principal de autenticación.
    Valida el JWT y retorna el usuario autenticado.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token inválido o expirado",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_token(credentials.credentials)
        user_id: str = payload.get("sub")
        token_type: str = payload.get("type")

        if user_id is None or token_type != "access":
            raise credentials_exception

    except JWTError:
        raise credentials_exception

    user = db.query(User).filter(
        User.id == UUID(user_id),
        User.is_active == True,
    ).first()

    if user is None:
        raise credentials_exception

    return user


def get_current_active_user(
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    """Verifica que el usuario esté activo."""
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cuenta desactivada",
        )
    return current_user


# ── Factories de permisos por rol ─────────────────────────────────────────
def require_role(required_role: UserRole):
    """
    Factory que genera una dependencia de verificación de rol.
    Uso: Depends(require_role(UserRole.ADMIN))
    """
    def role_checker(
        current_user: Annotated[User, Depends(get_current_active_user)],
    ) -> User:
        if not has_permission(current_user.role, required_role):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Se requiere rol '{required_role.value}' o superior",
            )
        return current_user
    return role_checker


# ── Shortcuts de roles comunes ─────────────────────────────────────────────
CurrentUser = Annotated[User, Depends(get_current_active_user)]
AdminUser = Annotated[User, Depends(require_role(UserRole.ADMIN))]
SuperAdminUser = Annotated[User, Depends(require_role(UserRole.SUPER_ADMIN))]
AsesorUser = Annotated[User, Depends(require_role(UserRole.ASESOR))]
