"""
DataOff — Servicio de Autenticación
Encapsula toda la lógica de negocio relacionada con auth.
Los routers solo llaman a este servicio, no tocan la DB directamente.
"""
from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.enums import UserRole
from app.core.security import (
    create_access_token,
    create_refresh_token,
    hash_password,
    verify_password,
)
from app.models.sync import RefreshToken
from app.models.user import User
from app.schemas.user import LoginRequest, TokenResponse, UserCreate, UserListResponse
from app.core.config import settings


class AuthService:

    def authenticate_user(
        self, db: Session, email: str, password: str
    ) -> Optional[User]:
        """Verifica credenciales. Retorna el User o None si son inválidas."""
        user = db.query(User).filter(
            User.email == email.lower().strip(),
            User.is_active == True,
        ).first()

        if not user:
            return None
        if not verify_password(password, user.hashed_password):
            return None
        return user

    def login(self, db: Session, request: LoginRequest) -> TokenResponse:
        """
        Proceso completo de login:
        1. Autenticar usuario
        2. Crear access_token y refresh_token
        3. Guardar refresh_token en DB
        4. Actualizar last_login
        """
        from fastapi import HTTPException, status

        user = self.authenticate_user(db, request.email, request.password)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Credenciales incorrectas",
                headers={"WWW-Authenticate": "Bearer"},
            )

        # Crear tokens
        access_token = create_access_token(subject=user.id, role=user.role)
        raw_refresh_token, refresh_expires = create_refresh_token(subject=user.id)

        # Guardar refresh token en DB
        refresh_token_obj = RefreshToken(
            user_id=user.id,
            token=raw_refresh_token,
            device_id=request.device_id,
            expires_at=refresh_expires,
            created_at=datetime.now(timezone.utc),
            revoked=False,
        )
        db.add(refresh_token_obj)

        # Actualizar last_login y device_id
        user.last_login = datetime.now(timezone.utc)
        if request.device_id:
            user.device_id = request.device_id
        db.flush()

        return TokenResponse(
            access_token=access_token,
            refresh_token=raw_refresh_token,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            user=UserListResponse.model_validate(user),
        )

    def refresh_access_token(self, db: Session, refresh_token: str) -> TokenResponse:
        """Renueva el access_token usando un refresh_token válido."""
        from fastapi import HTTPException, status
        from jose import JWTError
        from app.core.security import decode_token

        credentials_exception = HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token inválido o expirado",
        )

        try:
            payload = decode_token(refresh_token)
            if payload.get("type") != "refresh":
                raise credentials_exception
            user_id = UUID(payload["sub"])
        except (JWTError, ValueError):
            raise credentials_exception

        # Verificar que el token existe en DB y no fue revocado
        token_obj = db.query(RefreshToken).filter(
            RefreshToken.token == refresh_token,
            RefreshToken.revoked == False,
        ).first()

        if not token_obj or token_obj.expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
            raise credentials_exception

        user = db.query(User).filter(
            User.id == user_id, User.is_active == True
        ).first()

        if not user:
            raise credentials_exception

        # Revocar el token anterior (rotación de tokens)
        token_obj.revoked = True
        token_obj.revoked_at = datetime.now(timezone.utc)

        # Crear nuevos tokens
        new_access_token = create_access_token(subject=user.id, role=user.role)
        new_raw_refresh, new_refresh_expires = create_refresh_token(subject=user.id)

        new_token_obj = RefreshToken(
            user_id=user.id,
            token=new_raw_refresh,
            device_id=token_obj.device_id,
            expires_at=new_refresh_expires,
            created_at=datetime.now(timezone.utc),
            revoked=False,
        )
        db.add(new_token_obj)
        db.flush()

        return TokenResponse(
            access_token=new_access_token,
            refresh_token=new_raw_refresh,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
            user=UserListResponse.model_validate(user),
        )

    def logout(self, db: Session, refresh_token: str) -> bool:
        """Revoca el refresh token para el logout."""
        token_obj = db.query(RefreshToken).filter(
            RefreshToken.token == refresh_token
        ).first()
        if token_obj:
            token_obj.revoked = True
            token_obj.revoked_at = datetime.now(timezone.utc)
            db.flush()
            return True
        return False


auth_service = AuthService()
