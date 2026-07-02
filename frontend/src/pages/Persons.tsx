import { useEffect, useState, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { Plus, Search, RefreshCw, Eye, Trash2, Smartphone, Globe, Filter } from 'lucide-react'
import { personService } from '@/services'
import type { PersonListItem, PaginatedPersons } from '@/types'
import { format } from 'date-fns'
import { es } from 'date-fns/locale'
import toast from 'react-hot-toast'

const SYNC_SOURCE_LABELS: Record<string, { label: string; icon: typeof Smartphone; color: string }> = {
  mobile: { label: 'APK', icon: Smartphone, color: 'var(--color-accent)' },
  web:    { label: 'Web', icon: Globe,       color: 'var(--color-violet)' },
  api:    { label: 'API', icon: Globe,       color: 'var(--color-info)' },
}

export default function PersonsPage() {
  const navigate = useNavigate()
  const [data, setData] = useState<PaginatedPersons | null>(null)
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)

  const fetchPersons = useCallback(async () => {
    setLoading(true)
    try {
      const result = await personService.list({ page, page_size: 20, search: search || undefined })
      setData(result)
    } finally {
      setLoading(false)
    }
  }, [page, search])

  useEffect(() => { fetchPersons() }, [fetchPersons])

  // Debounce search
  const [searchInput, setSearchInput] = useState('')
  useEffect(() => {
    const timer = setTimeout(() => {
      setSearch(searchInput)
      setPage(1)
    }, 400)
    return () => clearTimeout(timer)
  }, [searchInput])

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`¿Eliminar a ${name}?`)) return
    try {
      await personService.delete(id)
      toast.success('Persona eliminada')
      fetchPersons()
    } catch {
      toast.error('Error al eliminar')
    }
  }

  return (
    <div className="p-6 space-y-5 animate-fade-in">

      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold" style={{ color: 'var(--color-text-primary)' }}>
            Personas
          </h1>
          <p style={{ color: 'var(--color-text-secondary)', fontSize: '0.875rem' }}>
            {data?.total.toLocaleString() ?? '—'} registros totales · Ordenados por fecha de captura
          </p>
        </div>
        <div className="flex gap-2">
          <button onClick={fetchPersons} className="btn btn-secondary btn-sm" disabled={loading}>
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            Actualizar
          </button>
          <button onClick={() => navigate('/persons/new')} className="btn btn-primary btn-sm">
            <Plus className="w-4 h-4" />
            Nueva Persona
          </button>
        </div>
      </div>

      {/* Buscador */}
      <div className="card p-4">
        <div className="flex gap-3 items-center">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4"
              style={{ color: 'var(--color-text-muted)' }} />
            <input
              id="search-persons"
              type="text"
              placeholder="Buscar por nombre, documento..."
              className="input"
              style={{ paddingLeft: '2.5rem' }}
              value={searchInput}
              onChange={e => setSearchInput(e.target.value)}
            />
          </div>
          <button className="btn btn-secondary btn-sm">
            <Filter className="w-4 h-4" />
            Filtros
          </button>
        </div>
      </div>

      {/* Tabla */}
      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>Persona</th>
              <th>Documento</th>
              <th>Ciudad</th>
              <th>Origen</th>
              <th>Capturado</th>
              <th>Contactos</th>
              <th>Estado Sync</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              [...Array(8)].map((_, i) => (
                <tr key={i}>
                  {[...Array(8)].map((_, j) => (
                    <td key={j}><div className="skeleton h-4 w-full" /></td>
                  ))}
                </tr>
              ))
            ) : data?.items.length === 0 ? (
              <tr>
                <td colSpan={8}>
                  <div className="flex flex-col items-center py-12 gap-2"
                    style={{ color: 'var(--color-text-muted)' }}>
                    <Search className="w-10 h-10 opacity-30" />
                    <p>No se encontraron personas</p>
                  </div>
                </td>
              </tr>
            ) : (
              data?.items.map((person) => {
                const src = SYNC_SOURCE_LABELS[person.sync_source] || SYNC_SOURCE_LABELS.web
                const SrcIcon = src.icon
                return (
                  <tr key={person.id}>
                    <td>
                      <div>
                        <p className="font-medium" style={{ color: 'var(--color-text-primary)' }}>
                          {person.first_name} {person.last_name}
                        </p>
                        <p className="text-xs" style={{ color: 'var(--color-text-muted)' }}>
                          {person.id.slice(0, 8)}...
                        </p>
                      </div>
                    </td>
                    <td>
                      {person.document_number
                        ? <span className="font-mono text-xs">{person.document_type} {person.document_number}</span>
                        : <span style={{ color: 'var(--color-text-muted)' }}>—</span>}
                    </td>
                    <td>{person.city || <span style={{ color: 'var(--color-text-muted)' }}>—</span>}</td>
                    <td>
                      <span className="flex items-center gap-1.5">
                        <SrcIcon className="w-3.5 h-3.5" style={{ color: src.color }} />
                        <span className="text-xs" style={{ color: src.color }}>{src.label}</span>
                      </span>
                    </td>
                    <td>
                      <div>
                        <p className="text-xs">{format(new Date(person.captured_at), 'dd MMM yyyy', { locale: es })}</p>
                        <p className="text-xs" style={{ color: 'var(--color-text-muted)' }}>
                          {format(new Date(person.captured_at), 'HH:mm')}
                        </p>
                      </div>
                    </td>
                    <td>
                      <span className="badge badge-accent">{person.contacts_count}</span>
                    </td>
                    <td>
                      <span className={`badge ${person.sync_status === 'synced' ? 'badge-success' : person.sync_status === 'pending' ? 'badge-warning' : 'badge-danger'}`}>
                        {person.sync_status}
                      </span>
                    </td>
                    <td>
                      <div className="flex gap-1">
                        <button onClick={() => navigate(`/persons/${person.id}`)} className="btn btn-ghost btn-icon">
                          <Eye className="w-4 h-4" />
                        </button>
                        <button onClick={() => handleDelete(person.id, `${person.first_name} ${person.last_name}`)}
                          className="btn btn-ghost btn-icon">
                          <Trash2 className="w-4 h-4" style={{ color: 'var(--color-danger)' }} />
                        </button>
                      </div>
                    </td>
                  </tr>
                )
              })
            )}
          </tbody>
        </table>
      </div>

      {/* Paginación */}
      {data && data.pages > 1 && (
        <div className="flex items-center justify-between">
          <p className="text-sm" style={{ color: 'var(--color-text-muted)' }}>
            Página {data.page} de {data.pages} · {data.total} resultados
          </p>
          <div className="flex gap-2">
            <button className="btn btn-secondary btn-sm" disabled={page === 1}
              onClick={() => setPage(p => p - 1)}>Anterior</button>
            <button className="btn btn-secondary btn-sm" disabled={page === data.pages}
              onClick={() => setPage(p => p + 1)}>Siguiente</button>
          </div>
        </div>
      )}
    </div>
  )
}
