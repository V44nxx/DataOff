import { useEffect, useState } from 'react'
import {
  Users, RefreshCw, Activity, Smartphone, Globe,
  TrendingUp, Clock, CheckCircle, AlertCircle, ArrowUpRight,
} from 'lucide-react'
import { dashboardService, syncService } from '@/services'
import type { DashboardStats, SyncLog } from '@/types'
import { format, formatDistanceToNow } from 'date-fns'
import { es } from 'date-fns/locale'
import {
  AreaChart, Area, XAxis, YAxis, Tooltip, ResponsiveContainer, PieChart, Pie, Cell,
} from 'recharts'

export default function DashboardPage() {
  const [stats, setStats] = useState<DashboardStats | null>(null)
  const [syncLogs, setSyncLogs] = useState<SyncLog[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    Promise.all([
      dashboardService.getStats(),
      syncService.getLogs(10),
    ]).then(([s, logs]) => {
      setStats(s)
      setSyncLogs(logs)
    }).finally(() => setLoading(false))
  }, [])

  if (loading) return <DashboardSkeleton />

  const syncSourceData = stats ? [
    { name: 'Mobile', value: stats.sync_sources.mobile, color: '#6366f1' },
    { name: 'Web', value: stats.sync_sources.web, color: '#8b5cf6' },
  ] : []

  const overviewCards = stats ? [
    {
      label: 'Personas Registradas',
      value: stats.overview.total_persons.toLocaleString(),
      sub: `+${stats.activity.persons_last_7_days} esta semana`,
      icon: Users,
      color: '#6366f1',
      bg: 'rgba(99,102,241,0.1)',
    },
    {
      label: 'Sincronizaciones',
      value: stats.overview.total_syncs.toLocaleString(),
      sub: `${stats.activity.syncs_last_7_days} últimos 7 días`,
      icon: RefreshCw,
      color: '#8b5cf6',
      bg: 'rgba(139,92,246,0.1)',
    },
    {
      label: 'Usuarios Activos',
      value: stats.overview.total_users.toLocaleString(),
      sub: 'En el sistema',
      icon: Activity,
      color: '#10b981',
      bg: 'rgba(16,185,129,0.1)',
    },
    {
      label: 'Contactos Capturados',
      value: stats.overview.total_contacts.toLocaleString(),
      sub: 'Normalizados en BD',
      icon: TrendingUp,
      color: '#f59e0b',
      bg: 'rgba(245,158,11,0.1)',
    },
  ] : []

  return (
    <div className="p-6 flex flex-col gap-6 animate-fade-in">

      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold" style={{ color: 'var(--color-text-primary)' }}>
          Dashboard
        </h1>
        <p style={{ color: 'var(--color-text-secondary)', fontSize: '0.875rem' }}>
          Vista general del sistema DataOff
        </p>
      </div>

      {/* Stat Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
        {overviewCards.map((card) => {
          const Icon = card.icon
          return (
            <div key={card.label} className="stat-card">
              <div className="flex items-start justify-between mb-4">
                <div className="w-10 h-10 rounded-xl flex items-center justify-center"
                  style={{ background: card.bg }}>
                  <Icon className="w-5 h-5" style={{ color: card.color }} />
                </div>
                <ArrowUpRight className="w-4 h-4" style={{ color: 'var(--color-text-muted)' }} />
              </div>
              <p className="text-3xl font-bold mb-1" style={{ color: 'var(--color-text-primary)' }}>
                {card.value}
              </p>
              <p className="text-sm font-medium mb-1" style={{ color: 'var(--color-text-secondary)' }}>
                {card.label}
              </p>
              <p className="text-xs" style={{ color: 'var(--color-text-muted)' }}>{card.sub}</p>
            </div>
          )
        })}
      </div>

      {/* Fila media: Fuentes + Logs recientes */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-4">

        {/* Gráfico de fuentes */}
        <div className="card p-5">
          <h3 className="text-sm font-semibold mb-4" style={{ color: 'var(--color-text-secondary)' }}>
            ORIGEN DE REGISTROS
          </h3>
          {syncSourceData[0]?.value || syncSourceData[1]?.value ? (
            <div className="flex items-center gap-4">
              <ResponsiveContainer width="100%" height={120}>
                <PieChart>
                  <Pie data={syncSourceData} cx="50%" cy="50%" innerRadius={35} outerRadius={55}
                    dataKey="value" strokeWidth={0}>
                    {syncSourceData.map((entry, i) => (
                      <Cell key={i} fill={entry.color} />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{ background: 'var(--color-bg-card)', border: '1px solid var(--color-border)', borderRadius: 8 }}
                    labelStyle={{ color: 'var(--color-text-primary)' }} />
                </PieChart>
              </ResponsiveContainer>
              <div className="flex flex-col gap-2 flex-shrink-0">
                {syncSourceData.map(d => (
                  <div key={d.name} className="flex items-center gap-2">
                    <div className="w-2 h-2 rounded-full" style={{ background: d.color }} />
                    <div>
                      <p className="text-xs font-medium" style={{ color: 'var(--color-text-primary)' }}>{d.name}</p>
                      <p className="text-xs" style={{ color: 'var(--color-text-muted)' }}>{d.value.toLocaleString()}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div className="flex items-center justify-center h-28" style={{ color: 'var(--color-text-muted)' }}>
              <div className="flex flex-col items-center gap-2">
                <Smartphone className="w-8 h-8 opacity-30" />
                <Globe className="w-6 h-6 opacity-20" />
                <p className="text-xs">Sin datos aún</p>
              </div>
            </div>
          )}
          <div className="flex gap-3 mt-4 pt-4" style={{ borderTop: '1px solid var(--color-border)' }}>
            <div className="flex items-center gap-1.5">
              <Smartphone className="w-3 h-3" style={{ color: '#6366f1' }} />
              <span className="text-xs" style={{ color: 'var(--color-text-muted)' }}>APK Flutter</span>
            </div>
            <div className="flex items-center gap-1.5">
              <Globe className="w-3 h-3" style={{ color: '#8b5cf6' }} />
              <span className="text-xs" style={{ color: 'var(--color-text-muted)' }}>Dashboard Web</span>
            </div>
          </div>
        </div>

        {/* Sincronizaciones recientes */}
        <div className="card p-5 lg:col-span-2">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-sm font-semibold" style={{ color: 'var(--color-text-secondary)' }}>
              SINCRONIZACIONES RECIENTES
            </h3>
            <RefreshCw className="w-4 h-4" style={{ color: 'var(--color-text-muted)' }} />
          </div>

          {syncLogs.length === 0 ? (
            <div className="flex flex-col items-center justify-center py-8 gap-2"
              style={{ color: 'var(--color-text-muted)' }}>
              <RefreshCw className="w-8 h-8 opacity-30" />
              <p className="text-sm">Sin sincronizaciones registradas</p>
            </div>
          ) : (
            <div className="flex flex-col gap-2">
              {syncLogs.map(log => (
                <div key={log.id} className="flex items-center gap-3 p-3 rounded-lg"
                  style={{ background: 'var(--color-bg-elevated)' }}>
                  <div>
                    {log.status === 'success'
                      ? <CheckCircle className="w-4 h-4" style={{ color: 'var(--color-success)' }} />
                      : log.status === 'partial'
                      ? <AlertCircle className="w-4 h-4" style={{ color: 'var(--color-warning)' }} />
                      : <AlertCircle className="w-4 h-4" style={{ color: 'var(--color-danger)' }} />}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-sm font-medium truncate" style={{ color: 'var(--color-text-primary)' }}>
                      {log.device_id || 'Dispositivo desconocido'}
                    </p>
                    <p className="text-xs" style={{ color: 'var(--color-text-muted)' }}>
                      {log.records_sent} registros enviados
                    </p>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <span className={`badge ${log.status === 'success' ? 'badge-success' : log.status === 'partial' ? 'badge-warning' : 'badge-danger'}`}>
                      {log.status}
                    </span>
                    <p className="text-xs mt-1" style={{ color: 'var(--color-text-muted)' }}>
                      {formatDistanceToNow(new Date(log.synced_at), { addSuffix: true, locale: es })}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

function DashboardSkeleton() {
  return (
    <div className="p-6 flex flex-col gap-6">
      <div className="flex flex-col gap-2">
        <div className="skeleton h-8 w-48" />
        <div className="skeleton h-4 w-64" />
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
        {[...Array(4)].map((_, i) => (
          <div key={i} className="card p-6 flex flex-col gap-3">
            <div className="skeleton h-10 w-10 rounded-xl" />
            <div className="skeleton h-8 w-20" />
            <div className="skeleton h-4 w-32" />
          </div>
        ))}
      </div>
    </div>
  )
}
