import { Wifi, Users, RefreshCw, BarChart3, ArrowRight } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import { useAuthStore } from '@/store/auth.store'

export default function HomePage() {
  const navigate = useNavigate()
  const { user } = useAuthStore()

  const features = [
    { icon: Wifi,     title: 'Offline-First',   desc: 'Captura datos sin internet. Se sincronizan automáticamente.', color: '#6366f1' },
    { icon: Users,    title: 'Personas',         desc: 'Registro normalizado con contactos ordenados por fecha real.', color: '#8b5cf6' },
    { icon: RefreshCw, title: 'Sync Engine',     desc: 'Motor de merge con resolución inteligente de conflictos.', color: '#10b981' },
    { icon: BarChart3, title: 'Reportes',        desc: 'Dashboard en tiempo real con estadísticas del sistema.', color: '#f59e0b' },
  ]

  return (
    <div className="min-h-screen p-6 animate-fade-in" style={{
      background: `
        radial-gradient(ellipse 80% 50% at 50% -10%, rgba(99,102,241,0.1) 0%, transparent 70%)
      `
    }}>
      <div className="max-w-4xl mx-auto">
        {/* Hero */}
        <div className="text-center py-12">
          <div className="inline-flex items-center justify-center w-20 h-20 rounded-3xl mb-6"
            style={{ background: 'var(--gradient-brand)', boxShadow: 'var(--shadow-glow)' }}>
            <Wifi className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-4xl font-bold mb-2">
            Bienvenido, <span className="text-gradient">{user?.full_name?.split(' ')[0]}</span>
          </h1>
          <p className="text-lg mb-8" style={{ color: 'var(--color-text-secondary)' }}>
            Sistema Offline-First Empresarial · DataOff v1.0.0
          </p>
          <button onClick={() => navigate('/dashboard')} className="btn btn-primary btn-lg gap-2">
            Ir al Dashboard
            <ArrowRight className="w-5 h-5" />
          </button>
        </div>

        {/* Features */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
          {features.map(f => {
            const Icon = f.icon
            return (
              <div key={f.title} className="card p-6 flex gap-4">
                <div className="w-10 h-10 rounded-xl flex items-center justify-center flex-shrink-0"
                  style={{ background: `${f.color}18` }}>
                  <Icon className="w-5 h-5" style={{ color: f.color }} />
                </div>
                <div>
                  <h3 className="font-semibold mb-1" style={{ color: 'var(--color-text-primary)' }}>{f.title}</h3>
                  <p className="text-sm" style={{ color: 'var(--color-text-secondary)' }}>{f.desc}</p>
                </div>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
