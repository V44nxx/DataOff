import { useEffect, useState } from 'react'
import { RefreshCw, Activity, CheckCircle, AlertCircle, XCircle, Monitor } from 'lucide-react'
import { syncService } from '@/services'
import type { SyncLog, SyncStats } from '@/types'
import { format, formatDistanceToNow } from 'date-fns'
import { es } from 'date-fns/locale'

export default function SyncPage() {
  const [logs, setLogs] = useState<SyncLog[]>([])
  const [stats, setStats] = useState<SyncStats | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    Promise.all([
      syncService.getLogs(50),
      syncService.getStats(),
    ]).then(([l, s]) => {
      setLogs(l)
      setStats(s)
    }).finally(() => setLoading(false))
  }, [])

  const statusIcon = (s: string) => {
    if (s === 'success') return <CheckCircle className="w-4 h-4" style={{ color: 'var(--color-success)' }} />
    if (s === 'partial') return <AlertCircle className="w-4 h-4" style={{ color: 'var(--color-warning)' }} />
    return <XCircle className="w-4 h-4" style={{ color: 'var(--color-danger)' }} />
  }

  return (
    <div className="p-6 space-y-6 animate-fade-in">
      <div>
        <h1 className="text-2xl font-bold" style={{ color: 'var(--color-text-primary)' }}>
          Sincronizaciones
        </h1>
        <p style={{ color: 'var(--color-text-secondary)', fontSize: '0.875rem' }}>
          Historial y estado del motor de sincronización
        </p>
      </div>

      {/* Stats de sync */}
      {stats && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          {[
            { label: 'Total Syncs', value: stats.total_syncs, color: '#6366f1', icon: RefreshCw },
            { label: 'Exitosas', value: stats.successful_syncs, color: '#10b981', icon: CheckCircle },
            { label: 'Fallidas', value: stats.failed_syncs, color: '#ef4444', icon: XCircle },
            { label: 'Dispositivos', value: stats.active_devices, color: '#f59e0b', icon: Monitor },
          ].map(item => {
            const Icon = item.icon
            return (
              <div key={item.label} className="stat-card">
                <Icon className="w-5 h-5 mb-3" style={{ color: item.color }} />
                <p className="text-2xl font-bold" style={{ color: 'var(--color-text-primary)' }}>
                  {item.value.toLocaleString()}
                </p>
                <p className="text-xs mt-1" style={{ color: 'var(--color-text-muted)' }}>{item.label}</p>
              </div>
            )
          })}
        </div>
      )}

      {/* Tabla de logs */}
      <div className="table-container">
        <table className="data-table">
          <thead>
            <tr>
              <th>Estado</th>
              <th>Dispositivo</th>
              <th>Fecha</th>
              <th>Enviados</th>
              <th>Insertados</th>
              <th>Actualizados</th>
              <th>Omitidos</th>
              <th>Conflictos</th>
            </tr>
          </thead>
          <tbody>
            {loading ? (
              [...Array(6)].map((_, i) => (
                <tr key={i}>
                  {[...Array(8)].map((_, j) => (
                    <td key={j}><div className="skeleton h-4 w-full" /></td>
                  ))}
                </tr>
              ))
            ) : logs.length === 0 ? (
              <tr>
                <td colSpan={8}>
                  <div className="flex flex-col items-center py-12 gap-2"
                    style={{ color: 'var(--color-text-muted)' }}>
                    <Activity className="w-10 h-10 opacity-30" />
                    <p>Sin sincronizaciones registradas</p>
                    <p className="text-xs">Los dispositivos móviles aparecerán aquí al sincronizar</p>
                  </div>
                </td>
              </tr>
            ) : (
              logs.map(log => (
                <tr key={log.id}>
                  <td>
                    <div className="flex items-center gap-2">
                      {statusIcon(log.status)}
                      <span className={`badge ${log.status === 'success' ? 'badge-success' : log.status === 'partial' ? 'badge-warning' : 'badge-danger'}`}>
                        {log.status}
                      </span>
                    </div>
                  </td>
                  <td>
                    <div>
                      <p className="text-xs font-mono truncate max-w-32" style={{ color: 'var(--color-text-primary)' }}>
                        {log.device_id || '—'}
                      </p>
                    </div>
                  </td>
                  <td>
                    <div>
                      <p className="text-xs">{format(new Date(log.synced_at), 'dd MMM yyyy HH:mm', { locale: es })}</p>
                      <p className="text-xs" style={{ color: 'var(--color-text-muted)' }}>
                        {formatDistanceToNow(new Date(log.synced_at), { addSuffix: true, locale: es })}
                      </p>
                    </div>
                  </td>
                  <td><span className="font-mono text-sm">{log.records_sent}</span></td>
                  <td><span className="font-mono text-sm" style={{ color: 'var(--color-success)' }}>{log.records_inserted}</span></td>
                  <td><span className="font-mono text-sm" style={{ color: 'var(--color-info)' }}>{log.records_updated}</span></td>
                  <td><span className="font-mono text-sm" style={{ color: 'var(--color-text-muted)' }}>{log.records_skipped}</span></td>
                  <td>
                    {log.conflicts_resolved > 0
                      ? <span className="badge badge-warning">{log.conflicts_resolved}</span>
                      : <span style={{ color: 'var(--color-text-muted)' }}>0</span>}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
