import { useState, useEffect } from 'react'
import { NavLink, Outlet, useNavigate, useLocation } from 'react-router-dom'
import {
  LayoutDashboard, Users, RefreshCw, BarChart3, Home, Wifi, WifiOff,
  LogOut, ChevronLeft, ChevronRight, User, Menu, X, Settings,
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
  const location = useLocation()
  const [collapsed, setCollapsed] = useState(false)
  const [mobileOpen, setMobileOpen] = useState(false)
  const [isOnline] = useState(navigator.onLine)

  // Cerrar el drawer en móvil cuando cambie la ruta
  useEffect(() => {
    setMobileOpen(false)
  }, [location.pathname])

  // Prevenir scroll del body cuando el menú móvil está abierto
  useEffect(() => {
    if (mobileOpen) {
      document.body.style.overflow = 'hidden'
    } else {
      document.body.style.overflow = ''
    }
    return () => {
      document.body.style.overflow = ''
    }
  }, [mobileOpen])

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
    <div className="flex h-screen overflow-hidden w-full relative" style={{ background: 'var(--color-bg-base)' }}>

      {/* ── Backdrop móvil ──────────────────────────────────── */}
      {mobileOpen && (
        <div
          className="fixed inset-0 bg-black/65 backdrop-blur-sm z-40 md:hidden animate-fade-in"
          onClick={() => setMobileOpen(false)}
          aria-hidden="true"
        />
      )}

      {/* ── Sidebar (Drawer en móvil, Sidebar en Desktop) ──── */}
      <aside
        className={`fixed md:static inset-y-0 left-0 z-50 flex flex-col transition-all duration-300 ease-in-out flex-shrink-0 shadow-2xl md:shadow-none ${
          mobileOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0'
        }`}
        style={{
          width: mobileOpen ? '16.5rem' : collapsed ? '4.5rem' : '16rem',
          background: 'var(--color-bg-surface)',
          borderRight: '1px solid var(--color-border)',
        }}>

        {/* Logo y Encabezado */}
        <div className="flex items-center justify-between px-4 py-4 md:py-5 border-b"
          style={{ borderColor: 'var(--color-border)', minHeight: '4.25rem' }}>
          <div className="flex items-center gap-3 min-w-0">
            <div className="w-9 h-9 rounded-xl flex items-center justify-center flex-shrink-0"
              style={{ background: 'var(--gradient-brand)', boxShadow: 'var(--shadow-glow)' }}>
              <Wifi className="w-5 h-5 text-white" />
            </div>
            {(!collapsed || mobileOpen) && (
              <div className="animate-fade-in truncate">
                <h1 className="text-base font-bold text-gradient leading-none">DataOff</h1>
                <p className="text-xs mt-0.5" style={{ color: 'var(--color-text-muted)' }}>v1.0.0</p>
              </div>
            )}
          </div>

          {/* Botón cerrar en móvil */}
          <button
            onClick={() => setMobileOpen(false)}
            className="md:hidden btn-icon btn-ghost p-1.5 rounded-lg text-gray-400 hover:text-white"
            aria-label="Cerrar menú">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Nav items */}
        <nav className="flex-1 overflow-y-auto p-3 space-y-1">
          {NAV_ITEMS.map(({ to, icon: Icon, label, exact }) => (
            <NavLink
              key={to}
              to={to}
              end={exact}
              onClick={() => setMobileOpen(false)}
              className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
              title={collapsed && !mobileOpen ? label : undefined}>
              <Icon className="w-4 h-4 flex-shrink-0" />
              {(!collapsed || mobileOpen) && <span className="truncate">{label}</span>}
            </NavLink>
          ))}
        </nav>

        {/* Indicador online/offline */}
        <div className="px-3 pb-2">
          <div className="flex items-center gap-2 px-3 py-2 rounded-lg"
            style={{ background: 'var(--color-bg-elevated)' }}>
            <div className={`glow-dot ${isOnline ? '' : 'offline'}`}
              style={{ width: 8, height: 8, flexShrink: 0 }} />
            {(!collapsed || mobileOpen) && (
              <span className="text-xs font-medium" style={{
                color: isOnline ? 'var(--color-success)' : 'var(--color-danger)'
              }}>
                {isOnline ? 'Conectado' : 'Sin conexión'}
              </span>
            )}
          </div>
        </div>

        {/* Usuario y Logout */}
        <div className="p-3 border-t" style={{ borderColor: 'var(--color-border)' }}>
          <div className="flex items-center gap-3 px-2 py-2">
            <div className="w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 font-bold text-sm"
              style={{ background: 'var(--gradient-brand)', color: 'white' }}>
              {user?.full_name?.[0]?.toUpperCase() || 'U'}
            </div>
            {(!collapsed || mobileOpen) && (
              <div className="flex-1 min-w-0 animate-fade-in">
                <p className="text-sm font-medium truncate" style={{ color: 'var(--color-text-primary)' }}>
                  {user?.full_name}
                </p>
                <p className="text-xs truncate" style={{ color: roleColors[user?.role || ''] }}>
                  {roleLabels[user?.role || ''] || user?.role}
                </p>
              </div>
            )}
            {(!collapsed || mobileOpen) && (
              <button onClick={handleLogout} className="btn-icon btn-ghost p-1.5"
                title="Cerrar sesión">
                <LogOut className="w-4 h-4" style={{ color: 'var(--color-text-muted)' }} />
              </button>
            )}
          </div>
        </div>

        {/* Toggle collapse (solo visible en pantallas medianas y grandes) */}
        <button
          onClick={() => setCollapsed(!collapsed)}
          className="hidden md:flex absolute -right-3 top-20 w-6 h-6 rounded-full items-center justify-center z-10"
          style={{
            background: 'var(--color-bg-elevated)',
            border: '1px solid var(--color-border)',
            color: 'var(--color-text-muted)',
            cursor: 'pointer',
          }}
          aria-label={collapsed ? 'Expandir menú' : 'Colapsar menú'}>
          {collapsed
            ? <ChevronRight className="w-3 h-3" />
            : <ChevronLeft className="w-3 h-3" />}
        </button>
      </aside>

      {/* ── Contenedor principal con Header móvil ──────────── */}
      <div className="flex-1 flex flex-col h-screen overflow-hidden min-w-0">

        {/* Barra superior solo en móvil */}
        <header
          className="md:hidden flex items-center justify-between px-4 py-3 border-b flex-shrink-0 z-20"
          style={{
            background: 'var(--color-bg-surface)',
            borderColor: 'var(--color-border)',
          }}>
          <div className="flex items-center gap-3">
            <button
              onClick={() => setMobileOpen(true)}
              className="btn-icon btn-ghost p-2 rounded-lg text-gray-300 hover:text-white"
              aria-label="Abrir menú de navegación">
              <Menu className="w-6 h-6" />
            </button>
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 rounded-lg flex items-center justify-center"
                style={{ background: 'var(--gradient-brand)' }}>
                <Wifi className="w-4 h-4 text-white" />
              </div>
              <span className="font-bold text-gradient text-sm">DataOff</span>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <div className={`glow-dot ${isOnline ? '' : 'offline'}`}
              style={{ width: 8, height: 8 }}
              title={isOnline ? 'Conectado' : 'Sin conexión'} />
            <div className="w-7 h-7 rounded-full flex items-center justify-center font-bold text-xs"
              style={{ background: 'var(--gradient-brand)', color: 'white' }}>
              {user?.full_name?.[0]?.toUpperCase() || 'U'}
            </div>
            <button onClick={handleLogout} className="btn-icon btn-ghost p-1.5 ml-1"
              title="Cerrar sesión">
              <LogOut className="w-4 h-4 text-gray-400 hover:text-red-400" />
            </button>
          </div>
        </header>

        {/* Contenido principal scrollable */}
        <main className="flex-1 overflow-y-auto w-full">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
