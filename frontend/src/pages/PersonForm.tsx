import { useState, useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Save, ArrowLeft, Plus, Trash2 } from 'lucide-react'
import { personService } from '@/services'
import type { PersonCreate, ContactCreate } from '@/types'
import toast from 'react-hot-toast'

// Regex para validaciones estrictas
const EMOJI_REGEX = /[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{FE00}-\u{FE0F}\u{1F900}-\u{1F9FF}\u{1FA70}-\u{1FAFF}\u{200D}]/u
const ONLY_LETTERS_REGEX = /^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]*$/
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

const containsEmoji = (str?: string) => {
  if (!str) return false
  return EMOJI_REGEX.test(str)
}

export default function PersonFormPage() {
  const navigate = useNavigate()
  const { id } = useParams()
  const isEditing = Boolean(id)

  const [loading, setLoading] = useState(false)
  const [formData, setFormData] = useState<PersonCreate>({
    first_name: '',
    last_name: '',
    document_type: 'CC',
    document_number: '',
    address: '',
    city: '',
    country: 'Colombia',
    profession: '',
    contacts: [
      { contact_type: 'phone', contact_value: '', is_primary: true, label: 'Principal' }
    ]
  })

  useEffect(() => {
    if (isEditing && id) {
      setLoading(true)
      personService.get(id).then(person => {
        setFormData({
          first_name: person.first_name,
          last_name: person.last_name,
          document_type: person.document_type || 'CC',
          document_number: person.document_number || '',
          address: person.address || '',
          city: person.city || '',
          country: person.country || 'Colombia',
          profession: person.profession || '',
          contacts: person.contacts?.length 
            ? person.contacts.map(c => ({
                contact_type: c.contact_type,
                contact_value: c.contact_value,
                is_primary: c.is_primary,
                label: c.label || ''
              }))
            : [{ contact_type: 'phone', contact_value: '', is_primary: true, label: 'Principal' }]
        })
      }).catch(() => {
        toast.error('Error al cargar la persona')
        navigate('/persons')
      }).finally(() => setLoading(false))
    }
  }, [id, isEditing, navigate])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    // 1. Validar Nombres y Apellidos
    const fName = formData.first_name.trim()
    const lName = formData.last_name.trim()

    if (!fName || fName.length < 2) {
      toast.error('El nombre debe tener al menos 2 caracteres')
      return
    }
    if (!ONLY_LETTERS_REGEX.test(fName) || /\d/.test(fName) || containsEmoji(fName)) {
      toast.error('El nombre solo puede contener letras y espacios (sin números ni emojis)')
      return
    }

    if (!lName || lName.length < 2) {
      toast.error('El apellido debe tener al menos 2 caracteres')
      return
    }
    if (!ONLY_LETTERS_REGEX.test(lName) || /\d/.test(lName) || containsEmoji(lName)) {
      toast.error('El apellido solo puede contener letras y espacios (sin números ni emojis)')
      return
    }

    // 2. Validar Documento si fue ingresado
    if (formData.document_number) {
      const doc = formData.document_number.trim()
      if (!/^\d{5,15}$/.test(doc)) {
        toast.error('El número de documento debe contener entre 5 y 15 dígitos numéricos')
        return
      }
    }

    // 3. Validar Emojis en otros campos
    if (containsEmoji(formData.address) || containsEmoji(formData.profession) || containsEmoji(formData.city) || containsEmoji(formData.country)) {
      toast.error('No se permiten emojis en ningún campo')
      return
    }

    // 4. Validar Contactos
    const activeContacts = (formData.contacts || []).filter(c => c.contact_value.trim() !== '')
    for (let i = 0; i < activeContacts.length; i++) {
      const c = activeContacts[i]
      if (containsEmoji(c.contact_value) || containsEmoji(c.label)) {
        toast.error(`El contacto #${i + 1} no puede contener emojis`)
        return
      }

      if (c.contact_type === 'phone' || c.contact_type === 'whatsapp') {
        const cleanedPhone = c.contact_value.trim()
        if (!/^\d{10}$/.test(cleanedPhone)) {
          toast.error(`El contacto #${i + 1} (${c.contact_type === 'whatsapp' ? 'WhatsApp' : 'Teléfono'}) debe tener exactamente 10 dígitos numéricos (ej. 3001234567)`)
          return
        }
      } else if (c.contact_type === 'email') {
        if (!EMAIL_REGEX.test(c.contact_value.trim())) {
          toast.error(`El contacto #${i + 1} debe ser un correo electrónico válido`)
          return
        }
      }
    }

    const payload = {
      ...formData,
      first_name: fName,
      last_name: lName,
      contacts: activeContacts
    }

    setLoading(true)
    try {
      if (isEditing && id) {
        await personService.update(id, payload)
        toast.success('Persona actualizada correctamente')
      } else {
        await personService.create(payload)
        toast.success('Persona creada exitosamente')
      }
      navigate('/persons')
    } catch (error) {
      toast.error('Hubo un error al guardar')
    } finally {
      setLoading(false)
    }
  }

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target

    // Bloqueo total de emojis en cualquier campo
    if (containsEmoji(value)) {
      toast.error('No se permiten emojis en ningún campo')
      return
    }

    // Reglas en tiempo real según el campo
    if (name === 'first_name' || name === 'last_name') {
      if (!ONLY_LETTERS_REGEX.test(value)) {
        toast.error('Solo se permiten letras en nombres y apellidos (sin números)')
        return
      }
    } else if (name === 'document_number') {
      if (value !== '' && !/^\d+$/.test(value)) {
        toast.error('El número de documento solo puede contener números')
        return
      }
      if (value.length > 15) return
    } else if (name === 'profession' || name === 'city') {
      if (value !== '' && !ONLY_LETTERS_REGEX.test(value)) {
        toast.error('Este campo solo debe contener letras y espacios')
        return
      }
    }

    setFormData(prev => ({ ...prev, [name]: value }))
  }

  const handleContactChange = (index: number, field: keyof ContactCreate, value: string) => {
    if (containsEmoji(value)) {
      toast.error('No se permiten emojis')
      return
    }

    const currentContact = formData.contacts?.[index]
    const contactType = field === 'contact_type' ? value : currentContact?.contact_type

    if (field === 'contact_value') {
      if (contactType === 'phone' || contactType === 'whatsapp') {
        if (value !== '' && !/^\d+$/.test(value)) {
          toast.error('Los teléfonos y WhatsApp solo admiten números')
          return
        }
        if (value.length > 10) {
          return
        }
      }
    }

    setFormData(prev => {
      const newContacts = [...(prev.contacts || [])]
      newContacts[index] = { ...newContacts[index], [field]: value }
      return { ...prev, contacts: newContacts }
    })
  }

  const addContact = () => {
    if ((formData.contacts?.length || 0) >= 3) {
      toast.error('Solo puedes tener un máximo de 3 contactos')
      return
    }
    setFormData(prev => ({
      ...prev,
      contacts: [...(prev.contacts || []), { contact_type: 'phone', contact_value: '', is_primary: false, label: '' }]
    }))
  }

  const removeContact = (index: number) => {
    setFormData(prev => {
      const newContacts = [...(prev.contacts || [])]
      newContacts.splice(index, 1)
      return { ...prev, contacts: newContacts }
    })
  }

  return (
    <div className="p-4 sm:p-6 space-y-4 sm:space-y-5 animate-fade-in max-w-4xl mx-auto w-full">
      <div className="flex items-center gap-3 sm:gap-4">
        <button type="button" onClick={() => navigate('/persons')} className="btn btn-ghost btn-icon p-2">
          <ArrowLeft className="w-5 h-5" />
        </button>
        <div>
          <h1 className="text-xl sm:text-2xl font-bold" style={{ color: 'var(--color-text-primary)' }}>
            {isEditing ? 'Editar Persona' : 'Nueva Persona'}
          </h1>
          <p className="text-xs sm:text-sm text-slate-400">
            {isEditing ? 'Modifica los datos personales y de contacto' : 'Registra una nueva persona en el sistema'}
          </p>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="flex flex-col gap-5 sm:gap-6">
        {/* Basic Info */}
        <div className="card p-4 sm:p-6 flex flex-col gap-4 sm:gap-5">
          <h2 className="text-base sm:text-lg font-semibold" style={{ color: 'var(--color-text-primary)' }}>Información Personal</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-5">
            <div className="flex flex-col gap-1.5">
              <label className="text-xs sm:text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Nombres * (Solo letras)</label>
              <input 
                required 
                type="text" 
                name="first_name" 
                className="input text-sm" 
                value={formData.first_name} 
                onChange={handleChange} 
                placeholder="Ej. Juan (sin números ni emojis)" 
              />
            </div>
            
            <div className="flex flex-col gap-1.5">
              <label className="text-xs sm:text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Apellidos * (Solo letras)</label>
              <input 
                required 
                type="text" 
                name="last_name" 
                className="input text-sm" 
                value={formData.last_name} 
                onChange={handleChange} 
                placeholder="Ej. Pérez (sin números ni emojis)" 
              />
            </div>

            <div className="flex flex-col gap-1.5">
              <label className="text-xs sm:text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Tipo Documento</label>
              <select name="document_type" className="input text-sm" value={formData.document_type} onChange={handleChange}>
                <option value="CC">Cédula de Ciudadanía (CC)</option>
                <option value="CE">Cédula de Extranjería (CE)</option>
                <option value="NIT">NIT</option>
                <option value="PP">Pasaporte (PP)</option>
                <option value="TI">Tarjeta de Identidad (TI)</option>
                <option value="OTHER">Otro</option>
              </select>
            </div>

            <div className="flex flex-col gap-1.5">
              <label className="text-xs sm:text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Número Documento (Solo números)</label>
              <input 
                type="text" 
                inputMode="numeric"
                name="document_number" 
                className="input text-sm" 
                value={formData.document_number} 
                onChange={handleChange} 
                placeholder="Ej. 1098765432"
                maxLength={15}
              />
            </div>

            <div className="flex flex-col gap-1.5 md:col-span-2">
              <label className="text-xs sm:text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Profesión u Ocupación</label>
              <input 
                type="text" 
                name="profession" 
                className="input text-sm" 
                value={formData.profession} 
                onChange={handleChange} 
                placeholder="Ej. Ingeniero de Sistemas (sin números)" 
              />
            </div>
          </div>
        </div>

        {/* Location Info */}
        <div className="card p-4 sm:p-6 flex flex-col gap-4 sm:gap-5">
          <h2 className="text-base sm:text-lg font-semibold" style={{ color: 'var(--color-text-primary)' }}>Ubicación</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 sm:gap-5">
            <div className="flex flex-col gap-1.5 md:col-span-2">
              <label className="text-xs sm:text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Dirección</label>
              <input 
                type="text" 
                name="address" 
                className="input text-sm" 
                value={formData.address} 
                onChange={handleChange} 
                placeholder="Ej. Calle 123 #45-67 (sin emojis)" 
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <label className="text-xs sm:text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Ciudad</label>
              <input 
                type="text" 
                name="city" 
                className="input text-sm" 
                value={formData.city} 
                onChange={handleChange} 
                placeholder="Ej. Medellín (solo letras)"
              />
            </div>
            <div className="flex flex-col gap-1.5">
              <label className="text-xs sm:text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>País</label>
              <input 
                type="text" 
                name="country" 
                className="input text-sm" 
                value={formData.country} 
                onChange={handleChange} 
                placeholder="Ej. Colombia"
              />
            </div>
          </div>
        </div>

        {/* Contacts Info */}
        <div className="card p-4 sm:p-6 flex flex-col gap-4 sm:gap-5">
          <div className="flex items-center justify-between gap-2">
            <div>
              <h2 className="text-base sm:text-lg font-semibold" style={{ color: 'var(--color-text-primary)' }}>Contactos (Máximo 3)</h2>
              <p className="text-xs text-slate-400">Teléfonos y WhatsApp requieren exactamente 10 dígitos</p>
            </div>
            <button type="button" onClick={addContact} className="btn btn-secondary btn-sm" disabled={(formData.contacts?.length || 0) >= 3}>
              <Plus className="w-4 h-4" />
              <span className="hidden sm:inline">Agregar Contacto</span>
              <span className="sm:hidden">Agregar</span>
            </button>
          </div>
          
          <div className="flex flex-col gap-3 sm:gap-4">
            {formData.contacts?.map((contact, index) => {
              const isPhoneType = contact.contact_type === 'phone' || contact.contact_type === 'whatsapp'
              return (
                <div key={index} className="p-3 sm:p-3 rounded-xl bg-slate-800/40 border border-slate-700/50 flex flex-col sm:flex-row gap-3 items-stretch sm:items-end">
                  <div className="flex flex-col gap-1.5 w-full sm:w-1/4">
                    <label className="text-xs sm:text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Tipo</label>
                    <select 
                      className="input text-sm" 
                      value={contact.contact_type} 
                      onChange={(e) => handleContactChange(index, 'contact_type', e.target.value)}
                    >
                      <option value="phone">Teléfono Móvil</option>
                      <option value="whatsapp">WhatsApp</option>
                      <option value="email">Correo Electrónico</option>
                      <option value="facebook">Facebook</option>
                      <option value="instagram">Instagram</option>
                      <option value="other">Otro</option>
                    </select>
                  </div>
                  <div className="flex flex-col gap-1.5 w-full sm:flex-1">
                    <div className="flex justify-between items-center">
                      <label className="text-xs sm:text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>
                        Valor {isPhoneType && <span className="text-xs text-blue-400 font-normal">(10 dígitos)</span>}
                      </label>
                      {isPhoneType && (
                        <span className={`text-xs ${contact.contact_value.length === 10 ? 'text-emerald-400 font-semibold' : 'text-amber-400'}`}>
                          {contact.contact_value.length}/10
                        </span>
                      )}
                    </div>
                    <input 
                      type={isPhoneType ? 'tel' : 'text'}
                      inputMode={isPhoneType ? 'numeric' : 'text'}
                      maxLength={isPhoneType ? 10 : undefined}
                      className="input text-sm" 
                      value={contact.contact_value} 
                      placeholder={isPhoneType ? 'Ej. 3001234567 (10 dígitos)' : 'Valor de contacto...'}
                      onChange={(e) => handleContactChange(index, 'contact_value', e.target.value)} 
                    />
                  </div>
                  <div className="flex flex-col gap-1.5 w-full sm:w-1/4">
                    <label className="text-xs sm:text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Etiqueta</label>
                    <input 
                      type="text" 
                      className="input text-sm" 
                      value={contact.label || ''} 
                      placeholder="Ej. Personal / Trabajo"
                      onChange={(e) => handleContactChange(index, 'label', e.target.value)} 
                    />
                  </div>
                  <button type="button" onClick={() => removeContact(index)} className="btn btn-ghost btn-icon self-end sm:self-auto sm:mb-1 p-2 text-red-400 hover:text-red-300" title="Eliminar contacto">
                    <Trash2 className="w-5 h-5" />
                  </button>
                </div>
              )
            })}
            {(!formData.contacts || formData.contacts.length === 0) && (
              <p className="text-sm" style={{ color: 'var(--color-text-muted)' }}>No hay contactos agregados.</p>
            )}
          </div>
        </div>

        <div className="flex flex-col-reverse sm:flex-row justify-end gap-3 pt-2">
          <button type="button" onClick={() => navigate('/persons')} className="btn btn-ghost w-full sm:w-auto" disabled={loading}>
            Cancelar
          </button>
          <button type="submit" className="btn btn-primary w-full sm:w-auto" disabled={loading}>
            <Save className="w-4 h-4" />
            {loading ? 'Guardando...' : (isEditing ? 'Guardar Cambios' : 'Guardar Registro')}
          </button>
        </div>
      </form>
    </div>
  )
}
