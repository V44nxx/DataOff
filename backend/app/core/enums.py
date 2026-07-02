"""
DataOff — Enumeraciones del dominio
Centralizadas aquí para reutilización en modelos, schemas y lógica.
"""
import enum


class UserRole(str, enum.Enum):
    """Roles del sistema con jerarquía de permisos."""
    SUPER_ADMIN = "super_admin"
    ADMIN = "admin"
    ASESOR = "asesor"
    AUDITOR = "auditor"


class SyncStatus(str, enum.Enum):
    """Estado de sincronización de un registro."""
    PENDING = "pending"
    SYNCED = "synced"
    FAILED = "failed"
    CONFLICT = "conflict"


class SyncSource(str, enum.Enum):
    """Origen de creación de un registro."""
    MOBILE = "mobile"
    WEB = "web"
    API = "api"


class ContactType(str, enum.Enum):
    """Tipos de contacto para la tabla contacts."""
    PHONE = "phone"
    EMAIL = "email"
    WHATSAPP = "whatsapp"
    FACEBOOK = "facebook"
    INSTAGRAM = "instagram"
    OTHER = "other"


class DocumentType(str, enum.Enum):
    """Tipos de documento de identidad."""
    CC = "CC"           # Cédula de ciudadanía
    CE = "CE"           # Cédula de extranjería
    NIT = "NIT"         # NIT empresa
    PP = "PP"           # Pasaporte
    TI = "TI"           # Tarjeta de identidad
    OTHER = "OTHER"


class Gender(str, enum.Enum):
    MALE = "M"
    FEMALE = "F"
    OTHER = "O"
    PREFER_NOT_TO_SAY = "N"


class SyncLogStatus(str, enum.Enum):
    """Estado de un log de sincronización."""
    SUCCESS = "success"
    PARTIAL = "partial"
    FAILED = "failed"


class SyncOperation(str, enum.Enum):
    """Operación solicitada en la cola de sincronización."""
    CREATE = "create"
    UPDATE = "update"
    DELETE = "delete"
