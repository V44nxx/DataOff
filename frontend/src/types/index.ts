// ═══════════════════════════════════════════════════════════════
// DataOff — Tipos TypeScript del dominio
// Espejo de los schemas Pydantic del backend
// ═══════════════════════════════════════════════════════════════

// ── Enums ──────────────────────────────────────────────────────
export type UserRole = 'super_admin' | 'admin' | 'asesor' | 'auditor'
export type SyncStatus = 'pending' | 'synced' | 'failed' | 'conflict'
export type SyncSource = 'mobile' | 'web' | 'api'
export type ContactType = 'phone' | 'email' | 'whatsapp' | 'facebook' | 'instagram' | 'other'
export type DocumentType = 'CC' | 'CE' | 'NIT' | 'PP' | 'TI' | 'OTHER'
export type Gender = 'M' | 'F' | 'O' | 'N'
export type SyncLogStatus = 'success' | 'partial' | 'failed'
export type SyncOperation = 'create' | 'update' | 'delete'

// ── Usuarios ───────────────────────────────────────────────────
export interface User {
  id: string
  email: string
  full_name: string
  role: UserRole
  is_active: boolean
  last_login?: string
  created_at: string
  updated_at: string
}

export interface TokenResponse {
  access_token: string
  refresh_token: string
  token_type: string
  expires_in: number
  user: User
}

export interface LoginRequest {
  email: string
  password: string
  device_id?: string
}

// ── Contactos ──────────────────────────────────────────────────
export interface Contact {
  id: string
  person_id: string
  contact_type: ContactType
  contact_value: string
  is_primary: boolean
  label?: string
  captured_at: string
  synced_at?: string
  sync_source: SyncSource
  is_deleted: boolean
  created_at: string
  updated_at: string
}

export interface ContactCreate {
  contact_type: ContactType
  contact_value: string
  is_primary?: boolean
  label?: string
}

// ── Personas ───────────────────────────────────────────────────
export interface Person {
  id: string
  user_id?: string
  first_name: string
  last_name: string
  document_type?: DocumentType
  document_number?: string
  birth_date?: string
  gender?: Gender
  address?: string
  city?: string
  department?: string
  country: string
  profession?: string
  notes?: string
  sync_source: SyncSource
  sync_status: SyncStatus
  captured_at: string
  synced_at?: string
  is_deleted: boolean
  created_at: string
  updated_at: string
  contacts: Contact[]
}

export interface PersonListItem {
  id: string
  first_name: string
  last_name: string
  document_type?: DocumentType
  document_number?: string
  city?: string
  sync_source: SyncSource
  sync_status: SyncStatus
  captured_at: string
  synced_at?: string
  contacts_count: number
}

export interface PaginatedPersons {
  items: PersonListItem[]
  total: number
  page: number
  page_size: number
  pages: number
}

export interface PersonCreate {
  first_name: string
  last_name: string
  document_type?: DocumentType
  document_number?: string
  birth_date?: string
  gender?: Gender
  address?: string
  city?: string
  department?: string
  country?: string
  profession?: string
  notes?: string
  contacts?: ContactCreate[]
}

// ── Sincronización ─────────────────────────────────────────────
export interface SyncLog {
  id: string
  user_id?: string
  device_id?: string
  synced_at: string
  records_sent: number
  records_inserted: number
  records_updated: number
  records_skipped: number
  conflicts_resolved: number
  status: SyncLogStatus
  error_message?: string
}

export interface SyncStats {
  total_syncs: number
  successful_syncs: number
  failed_syncs: number
  total_records_synced: number
  total_conflicts_resolved: number
  active_devices: number
  last_sync_at?: string
}

// ── Dashboard ──────────────────────────────────────────────────
export interface DashboardStats {
  overview: {
    total_persons: number
    total_contacts: number
    total_users: number
    total_syncs: number
  }
  activity: {
    persons_last_30_days: number
    persons_last_7_days: number
    syncs_last_7_days: number
  }
  sync_sources: {
    mobile: number
    web: number
  }
  recent_syncs: Array<{
    id: string
    device_id?: string
    synced_at: string
    records_sent: number
    status: SyncLogStatus
  }>
}

// ── API Response ───────────────────────────────────────────────
export interface ApiError {
  detail: string
  path?: string
}

export interface PaginationParams {
  page?: number
  page_size?: number
  search?: string
  city?: string
}
