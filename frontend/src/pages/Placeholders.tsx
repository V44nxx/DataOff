import { Construction } from 'lucide-react'

interface PlaceholderProps {
  title: string
  description?: string
}

export function PlaceholderPage({ title, description }: PlaceholderProps) {
  return (
    <div className="flex flex-col items-center justify-center min-h-96 gap-4 animate-fade-in">
      <div className="w-16 h-16 rounded-2xl flex items-center justify-center"
        style={{ background: 'var(--color-bg-elevated)', border: '1px solid var(--color-border)' }}>
        <Construction className="w-8 h-8" style={{ color: 'var(--color-accent)' }} />
      </div>
      <div className="text-center">
        <h2 className="text-xl font-semibold mb-1" style={{ color: 'var(--color-text-primary)' }}>{title}</h2>
        <p style={{ color: 'var(--color-text-secondary)', fontSize: '0.875rem' }}>
          {description || 'Esta sección está en desarrollo.'}
        </p>
      </div>
    </div>
  )
}

// ── Páginas placeholder ────────────────────────────────────────
export const UsersPage  = () => <PlaceholderPage title="Usuarios" description="Gestión de usuarios del sistema." />
export const ReportsPage = () => <PlaceholderPage title="Reportes" description="Generación de reportes y exportaciones." />
export const SettingsPage = () => <PlaceholderPage title="Configuración" description="Configuración general del sistema." />
