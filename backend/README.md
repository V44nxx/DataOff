# DataOff — Backend FastAPI

Sistema Offline-First Empresarial — Backend API

## Inicio Rápido

### 1. Crear el entorno virtual

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate

# Linux/Mac
source venv/bin/activate
```

### 2. Instalar dependencias

```bash
pip install -r requirements.txt
```

### 3. Configurar variables de entorno

```bash
cp .env.example .env
# Edita .env con tus credenciales de PostgreSQL
```

### 4. Crear la base de datos PostgreSQL

```sql
-- En psql o pgAdmin:
CREATE USER dataoff_user WITH PASSWORD 'dataoff_password';
CREATE DATABASE dataoff_db OWNER dataoff_user;
GRANT ALL PRIVILEGES ON DATABASE dataoff_db TO dataoff_user;
```

### 5. Ejecutar migraciones

```bash
alembic upgrade head
```

### 6. Iniciar el servidor

```bash
# Desarrollo (con reload automático)
python -m app.main

# O con uvicorn directo
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 7. Verificar

- API: http://localhost:8000
- Docs: http://localhost:8000/docs
- Health: http://localhost:8000/health

## Estructura del Proyecto

```
backend/
├── app/
│   ├── api/              # Routers (endpoints)
│   │   ├── auth.py       # Login, refresh, logout
│   │   ├── users.py      # CRUD usuarios
│   │   ├── persons.py    # CRUD personas + contactos
│   │   ├── sync.py       # Sincronización offline
│   │   └── dashboard.py  # Estadísticas
│   ├── core/             # Configuración y seguridad
│   │   ├── config.py     # Variables de entorno
│   │   ├── enums.py      # Enumeraciones del dominio
│   │   ├── security.py   # JWT + bcrypt
│   │   └── dependencies.py  # Inyección de dependencias
│   ├── db/               # Capa de base de datos
│   │   ├── base_model.py # Clase base SQLAlchemy
│   │   ├── session.py    # Engine + SessionLocal
│   │   └── init_db.py    # Seeder inicial
│   ├── models/           # Modelos ORM
│   │   ├── user.py       # Usuario
│   │   ├── person.py     # Persona + Contacto
│   │   └── sync.py       # RefreshToken + SyncLog
│   ├── schemas/          # Pydantic schemas
│   │   ├── user.py
│   │   ├── person.py
│   │   └── sync.py
│   ├── services/         # Lógica de negocio
│   │   ├── auth_service.py
│   │   ├── person_service.py
│   │   └── sync_service.py
│   ├── sync/             # Motor de sincronización
│   │   └── merge_engine.py
│   └── main.py           # Punto de entrada
├── alembic/              # Migraciones
├── requirements.txt
├── alembic.ini
└── .env
```

## Endpoints Principales

| Método | Endpoint | Descripción | Auth |
|--------|----------|-------------|------|
| POST | /api/v1/auth/login | Login | ❌ |
| POST | /api/v1/auth/refresh | Renovar token | ❌ |
| GET | /api/v1/auth/me | Perfil propio | ✅ |
| GET | /api/v1/persons | Listar personas | ✅ |
| POST | /api/v1/persons | Crear persona | ✅ |
| **POST** | **/api/v1/sync/push** | **Sincronizar desde APK** | ✅ |
| GET | /api/v1/sync/logs | Historial sync | ADMIN |
| GET | /api/v1/dashboard/stats | Estadísticas | ADMIN |

## Endpoint de Sincronización (APK → Servidor)

```json
POST /api/v1/sync/push
Authorization: Bearer <token>

{
  "device_id": "flutter-device-uuid",
  "records": [
    {
      "entity_type": "person",
      "operation": "create",
      "data": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "first_name": "Juan",
        "last_name": "Pérez",
        "captured_at": "2024-06-04T10:30:00Z",
        "updated_at": "2024-06-04T10:30:00Z"
      }
    }
  ]
}
```

## Roles de Usuario

| Rol | Nivel | Permisos |
|-----|-------|----------|
| super_admin | 4 | Todo |
| admin | 3 | Usuarios + Reportes |
| asesor | 2 | Captura de personas (propias) |
| auditor | 1 | Solo lectura |

## Primer Usuario

Al iniciar en modo `development`, se crea automáticamente:
- **Email**: admin@dataoff.com
- **Password**: Admin@DataOff2024
- **Rol**: super_admin
