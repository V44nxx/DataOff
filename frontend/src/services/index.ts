/**
 * DataOff — Servicios de API por módulo
 */
import api from './api'
import type {
  DashboardStats,
  LoginRequest,
  PaginatedPersons,
  PaginationParams,
  Person,
  PersonCreate,
  SyncLog,
  SyncStats,
  TokenResponse,
  User,
} from '@/types'

// ── Auth ────────────────────────────────────────────────────────
export const authService = {
  login: (data: LoginRequest) =>
    api.post<TokenResponse>('/auth/login', data).then(r => r.data),

  logout: (refresh_token: string) =>
    api.post('/auth/logout', { refresh_token }),

  me: () => api.get<User>('/auth/me').then(r => r.data),
}

// ── Personas ────────────────────────────────────────────────────
export const personService = {
  list: (params: PaginationParams = {}) =>
    api.get<PaginatedPersons>('/persons', { params }).then(r => r.data),

  get: (id: string) =>
    api.get<Person>(`/persons/${id}`).then(r => r.data),

  create: (data: PersonCreate) =>
    api.post<Person>('/persons', data).then(r => r.data),

  update: (id: string, data: Partial<PersonCreate>) =>
    api.patch<Person>(`/persons/${id}`, data).then(r => r.data),

  delete: (id: string) =>
    api.delete(`/persons/${id}`),
}

// ── Usuarios ────────────────────────────────────────────────────
export const userService = {
  list: () => api.get<User[]>('/users').then(r => r.data),
  get: (id: string) => api.get<User>(`/users/${id}`).then(r => r.data),
  create: (data: Partial<User> & { password: string }) =>
    api.post<User>('/users', data).then(r => r.data),
  update: (id: string, data: Partial<User>) =>
    api.patch<User>(`/users/${id}`, data).then(r => r.data),
  deactivate: (id: string) => api.delete(`/users/${id}`),
}

// ── Sincronización ─────────────────────────────────────────────
export const syncService = {
  getLogs: (limit = 50) =>
    api.get<SyncLog[]>('/sync/logs', { params: { limit } }).then(r => r.data),

  getStats: () =>
    api.get<SyncStats>('/sync/stats').then(r => r.data),
}

// ── Dashboard ──────────────────────────────────────────────────
export const dashboardService = {
  getStats: () =>
    api.get<DashboardStats>('/dashboard/stats').then(r => r.data),

  getPersonsByCity: (limit = 10) =>
    api.get<Array<{ city: string; count: number }>>('/dashboard/persons-by-city', {
      params: { limit },
    }).then(r => r.data),
}
