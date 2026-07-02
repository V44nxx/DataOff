import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Eye, EyeOff, Wifi, Lock, Mail, AlertCircle } from 'lucide-react'
import { useAuthStore } from '@/store/auth.store'
import toast from 'react-hot-toast'

export default function LoginPage() {
  const navigate = useNavigate()
  const { login, isLoading } = useAuthStore()
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    try {
      await login(email, password)
      toast.success('Bienvenido a DataOff')
      navigate('/dashboard')
    } catch {
      setError('Credenciales incorrectas. Verifica tu email y contraseña.')
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden"
      style={{ background: 'var(--color-bg-base)' }}>

      {/* Fondo animado con glow */}
      <div className="absolute inset-0 pointer-events-none" style={{
        background: `
          radial-gradient(ellipse 60% 50% at 50% 0%, rgba(99,102,241,0.12) 0%, transparent 70%),
          radial-gradient(ellipse 40% 40% at 80% 80%, rgba(139,92,246,0.08) 0%, transparent 60%)
        `
      }} />

      {/* Grid pattern */}
      <div className="absolute inset-0 pointer-events-none opacity-[0.03]"
        style={{
          backgroundImage: `linear-gradient(var(--color-border) 1px, transparent 1px),
            linear-gradient(90deg, var(--color-border) 1px, transparent 1px)`,
          backgroundSize: '40px 40px'
        }} />

      <div className="w-full max-w-md mx-4 animate-fade-in">

        {/* Logo + Título */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl mb-4"
            style={{ background: 'var(--gradient-brand)', boxShadow: 'var(--shadow-glow)' }}>
            <Wifi className="w-8 h-8 text-white" />
          </div>
          <h1 className="text-3xl font-bold text-gradient mb-1">DataOff</h1>
          <p style={{ color: 'var(--color-text-secondary)', fontSize: '0.9rem' }}>
            Sistema Offline-First Empresarial
          </p>
        </div>

        {/* Card de login */}
        <div className="card p-8">
          <h2 className="text-xl font-semibold mb-1" style={{ color: 'var(--color-text-primary)' }}>
            Iniciar Sesión
          </h2>
          <p className="mb-6 text-sm" style={{ color: 'var(--color-text-secondary)' }}>
            Accede a tu cuenta para continuar
          </p>

          {error && (
            <div className="flex items-start gap-3 p-3 rounded-lg mb-4"
              style={{ background: 'var(--color-danger-dim)', border: '1px solid rgba(239,68,68,0.25)' }}>
              <AlertCircle className="w-4 h-4 mt-0.5 flex-shrink-0" style={{ color: 'var(--color-danger)' }} />
              <p className="text-sm" style={{ color: 'var(--color-danger)' }}>{error}</p>
            </div>
          )}

          <form onSubmit={handleSubmit} className="flex flex-col gap-5">
            {/* Email */}
            <div>
              <label className="label">Correo electrónico</label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4"
                  style={{ color: 'var(--color-text-muted)' }} />
                <input
                  id="email"
                  type="email"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                  placeholder="admin@dataoff.com"
                  className="input"
                  style={{ paddingLeft: '2.5rem' }}
                  required
                  autoFocus
                />
              </div>
            </div>

            {/* Contraseña */}
            <div>
              <label className="label">Contraseña</label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4"
                  style={{ color: 'var(--color-text-muted)' }} />
                <input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="input"
                  style={{ paddingLeft: '2.5rem', paddingRight: '2.75rem' }}
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 p-0.5"
                  style={{ color: 'var(--color-text-muted)', background: 'none', border: 'none', cursor: 'pointer' }}>
                  {showPassword
                    ? <EyeOff className="w-4 h-4" />
                    : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            <button
              id="btn-login"
              type="submit"
              disabled={isLoading}
              className="btn btn-primary w-full"
              style={{ height: '2.75rem' }}>
              {isLoading
                ? <span className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                : 'Iniciar Sesión'}
            </button>
          </form>
        </div>

        {/* Indicador offline-first */}
        <div className="flex items-center justify-center gap-2 mt-6 text-xs"
          style={{ color: 'var(--color-text-muted)' }}>
          <div className="glow-dot" style={{ width: 6, height: 6 }} />
          Sistema funciona en modo offline · Versión 1.0.0
        </div>
      </div>
    </div>
  )
}
