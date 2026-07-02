"""
DataOff — Router de Usuarios
CRUD de usuarios del sistema. Solo ADMIN y SUPER_ADMIN.
"""
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.dependencies import AdminUser, SuperAdminUser, get_db
from app.core.enums import UserRole
from app.core.security import hash_password
from app.models.user import User
from app.schemas.user import UserCreate, UserListResponse, UserResponse, UserUpdate

router = APIRouter(prefix="/users", tags=["Usuarios"])


@router.get("", response_model=List[UserListResponse], summary="Listar usuarios")
def list_users(
    current_user: AdminUser,
    db: Session = Depends(get_db),
    role: Optional[UserRole] = Query(None, description="Filtrar por rol"),
    is_active: Optional[bool] = Query(None, description="Filtrar por estado"),
    search: Optional[str] = Query(None, description="Buscar por nombre o email"),
):
    """Lista todos los usuarios. Requiere rol ADMIN o superior."""
    query = db.query(User)
    if role:
        query = query.filter(User.role == role)
    if is_active is not None:
        query = query.filter(User.is_active == is_active)
    if search:
        term = f"%{search}%"
        query = query.filter(
            User.full_name.ilike(term) | User.email.ilike(term)
        )
    return query.order_by(User.created_at.desc()).all()


@router.post("", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(
    data: UserCreate,
    current_user: AdminUser,
    db: Session = Depends(get_db),
):
    """
    Crea un nuevo usuario.
    - ADMIN puede crear ASESOR y AUDITOR.
    - SUPER_ADMIN puede crear cualquier rol.
    """
    # Un ADMIN no puede crear SUPER_ADMIN
    if (
        current_user.role == UserRole.ADMIN
        and data.role == UserRole.SUPER_ADMIN
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="ADMIN no puede crear SUPER_ADMIN",
        )

    # Verificar email único
    existing = db.query(User).filter(User.email == data.email.lower()).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"El email '{data.email}' ya está registrado",
        )

    user = User(
        email=data.email.lower().strip(),
        hashed_password=hash_password(data.password),
        full_name=data.full_name,
        role=data.role,
        is_active=True,
    )
    db.add(user)
    db.flush()
    return user


@router.get("/{user_id}", response_model=UserResponse)
def get_user(
    user_id: UUID,
    current_user: AdminUser,
    db: Session = Depends(get_db),
):
    """Obtiene un usuario por ID."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")
    return user


@router.patch("/{user_id}", response_model=UserResponse)
def update_user(
    user_id: UUID,
    data: UserUpdate,
    current_user: AdminUser,
    db: Session = Depends(get_db),
):
    """Actualiza un usuario. ADMIN no puede promover a SUPER_ADMIN."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")

    if (
        current_user.role == UserRole.ADMIN
        and data.role == UserRole.SUPER_ADMIN
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="ADMIN no puede asignar rol SUPER_ADMIN",
        )

    update_data = data.model_dump(exclude_unset=True)
    if "password" in update_data:
        user.hashed_password = hash_password(update_data.pop("password"))

    for field, value in update_data.items():
        setattr(user, field, value)

    db.flush()
    return user


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def deactivate_user(
    user_id: UUID,
    current_user: SuperAdminUser,
    db: Session = Depends(get_db),
):
    """Desactiva un usuario (no se elimina físicamente). Solo SUPER_ADMIN."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado")
    if user.id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No puedes desactivar tu propia cuenta",
        )
    user.is_active = False
    db.flush()
