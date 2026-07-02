import { useState } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import {
  LayoutDashboard, Users, RefreshCw, FileText, Settings,
  BarChart3, Home, Wifi, WifiOff, LogOut, ChevronLeft, ChevronRight, User,
} from 'lucide-react'
import { useAuthStore } from '@/store/auth.store'
import toast from 'react-hot-toast'

const NAV_ITEMS = [
  { to: '/',          icon: Home,            label: 'Inicio',          exact: true },
  { to: '/dashboard', icon: LayoutDashboard, label: 'Dashboard' },
  { to: '/persons',   icon: Users,           label: 'Personas' },
  { to: '/sync',      icon: RefreshCw,       label: 'Sincronizaciones' },
  { to: '/users',     icon: User,            label: 'Usuarios' },
  { to: '/reports',   icon: BarChart3,       label: 'Reportes' },
  { to: '/settings',  icon: Settings,        label: 'Configuración' },
]

export default function AppLayout() {
  const { user, logout } = useAuthStore()
  const navigate = useNavigate()
  const [collapsed, setCollapsed] = useState(false)
  const [isOnline] = useState(navigator.onLine)

  const handleLogout = async () => {
    await logout()
    toast.success('Sesión cerrada')
    navigate('/login')
  }

  const roleColors: Record<string, string> = {
    super_admin: 'var(--color-violet)',
    admin:       'var(--color-accent)',
    asesor:      'var(--color-success)',
    auditor:     'var(--color-text-secondary)',
  }
  const roleLabels: Record<string, string> = {
    super_admin: 'Super Admin',
    admin: 'Administrador',
    asesor: 'Asesor',
    auditor: 'Auditor',
  }

  return (
    <div className="flex h-screen overflow-hidden" style={{ background: 'var(--color-bg-base)' }}>

      {/* ── Sidebar ──────────────────────────────────────── */}
      <aside
        className="flex flex-col relative transition-all duration-300 ease-in-out flex-shrink-0"
        style={{
          width: collapsed ? '4.5rem' : '16rem',
          background: 'var(--color-bg-surface)',
          borderRight: '1px solid var(--color-border)',
        }}>

        {/* Logo */}
        <div className="flex items-center gap-3 px-4 py-5 border-b"
          style={{ borderColor: 'var(--color-border)', minHeight: '4.5rem' }}>
          <div className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0"
            style={{ background: 'var(--gradient-brand)', boxShadow: 'var(--shadow-glow)' }}>
            <Wifi className="w-5 h-5 text-white" />
          </div>
          {!collapsed && (
            <div className="animate-fade-in">
              <h1 className="text-base font-bold text-gradient leading-none">DataOff</h1>
              <p className="text-xs mt-0.5" style={{ color: 'var(--color-text-muted)' }}>v1.0.0</p>
            </div>
          )}
        </div>

        {/* Nav items */}
        <nav className="flex-1 overflow-y-auto p-3 space-y-1">
          {NAV_ITEMS.map(({ to, icon: Icon, label, exact }) => (
            <NavLink
              key={to}
              to={to}
              end={exact}
              className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
              title={collapsed ? label : undefined}>
              <Icon className="w-4 h-4 flex-shrink-0" />
              {!collapsed && <span className="truncate">{label}</span>}
            </NavLink>
          ))}
        </nav>

        {/* Indicador online/offline */}
        <div className="px-3 pb-2">
          <div className="flex items-center gap-2 px-3 py-2 rounded-lg"
            style={{ background: 'var(--color-bg-elevated)' }}>
            <div className={`glow-dot ${isOnline ? '' : 'offline'}`}
              style={{ width: 8, height: 8, flexShrink: 0 }} />
            {!collapsed && (
              <span className="text-xs font-medium" style={{
                color: isOnline ? 'var(--color-success)' : 'var(--color-danger)'
              }}>
                {isOnline ? 'Conectado' : 'Sin conexión'}
              </span>
            )}
          </div>
        </div>

        {/* Usuario */}
        <div className="p-3 border-t" style={{ borderColor: 'var(--color-border)' }}>
          <div className="flex items-center gap-3 px-2 py-2">
            <div className="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 font-bold text-sm"
              style={{ background: 'var(--gradient-brand)', color: 'white' }}>
              {user?.full_name?.[0]?.toUpperCase() || 'U'}
            </div>
            {!collapsed && (
              <div className="flex-1 min-w-0 animate-fade-in">
                <p className="text-sm font-medium truncate" style={{ color: 'var(--color-text-primary)' }}>
                  {user?.full_name}
                </p>
                <p className="text-xs truncate" style={{ color: roleColors[user?.role || ''] }}>
                  {roleLabels[user?.role || ''] || user?.role}
                </p>
              </div>
            )}
            {!collapsed && (
              <button onClick={handleLogout} className="btn-icon btn-ghost"
                title="Cerrar sesión" style={{ padding: '0.375rem' }}>
                <LogOut className="w-4 h-4" style={{ color: 'var(--color-text-muted)' }} />
              </button>
            )}
          </div>
        </div>

        {/* Toggle collapse */}
        <button
          onClick={() => setCollapsed(!collapsed)}
          className="absolute -right-3 top-20 w-6 h-6 rounded-full flex items-center justify-center z-10"
          style={{
            background: 'var(--color-bg-elevated)',
            border: '1px solid var(--color-border)',
            color: 'var(--color-text-muted)',
            cursor: 'pointer',
          }}>
          {collapsed
            ? <ChevronRight className="w-3 h-3" />
            : <ChevronLeft className="w-3 h-3" />}
        </button>
      </aside>

      {/* ── Contenido principal ───────────────────────────── */}
      <main className="flex-1 overflow-y-auto">
        <Outlet />
      </main>
    </div>
  )
}
