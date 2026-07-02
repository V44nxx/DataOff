"""
DataOff — Router de Autenticación
Endpoints: login, refresh, logout, me
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.dependencies import CurrentUser, get_db
from app.schemas.user import (
    ChangePasswordRequest,
    LoginRequest,
    RefreshTokenRequest,
    TokenResponse,
    UserResponse,
)
from app.services.auth_service import auth_service
from app.core.security import hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["Autenticación"])


@router.post("/login", response_model=TokenResponse, summary="Iniciar sesión")
def login(request: LoginRequest, db: Session = Depends(get_db)):
    """
    Autentica al usuario y retorna access_token + refresh_token.
    
    - **email**: Correo electrónico del usuario
    - **password**: Contraseña
    - **device_id**: ID único del dispositivo (opcional, para mobile)
    """
    return auth_service.login(db, request)


@router.post("/refresh", response_model=TokenResponse, summary="Renovar token")
def refresh_token(request: RefreshTokenRequest, db: Session = Depends(get_db)):
    """
    Renueva el access_token usando el refresh_token.
    El refresh_token anterior queda invalidado (rotación de tokens).
    """
    return auth_service.refresh_access_token(db, request.refresh_token)


@router.post("/logout", summary="Cerrar sesión")
def logout(request: RefreshTokenRequest, db: Session = Depends(get_db)):
    """Revoca el refresh_token para invalidar la sesión."""
    revoked = auth_service.logout(db, request.refresh_token)
    return {"message": "Sesión cerrada correctamente", "revoked": revoked}


@router.get("/me", response_model=UserResponse, summary="Perfil del usuario actual")
def get_me(current_user: CurrentUser):
    """Retorna el perfil del usuario autenticado."""
    return current_user


@router.post("/change-password", summary="Cambiar contraseña")
def change_password(
    request: ChangePasswordRequest,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
):
    """Cambia la contraseña del usuario autenticado."""
    from fastapi import HTTPException, status

    if not verify_password(request.current_password, current_user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Contraseña actual incorrecta",
        )

    current_user.hashed_password = hash_password(request.new_password)
    db.flush()

    return {"message": "Contraseña actualizada correctamente"}
