import { useState, useEffect } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Save, ArrowLeft, Plus, Trash2 } from 'lucide-react'
import { personService } from '@/services'
import type { PersonCreate, ContactCreate } from '@/types'
import toast from 'react-hot-toast'

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
    
    // Filtrar contactos vacíos
    const payload = {
      ...formData,
      contacts: formData.contacts?.filter(c => c.contact_value.trim() !== '')
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
    setFormData(prev => ({ ...prev, [e.target.name]: e.target.value }))
  }

  const handleContactChange = (index: number, field: keyof ContactCreate, value: string) => {
    setFormData(prev => {
      const newContacts = [...(prev.contacts || [])]
      newContacts[index] = { ...newContacts[index], [field]: value }
      return { ...prev, contacts: newContacts }
    })
  }

  const addContact = () => {
    if ((formData.contacts?.length || 0) >= 3) {
      toast.error('Solo puedes agregar hasta 3 contactos')
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
    <div className="p-6 space-y-5 animate-fade-in max-w-4xl mx-auto">
      <div className="flex items-center gap-4">
        <button type="button" onClick={() => navigate('/persons')} className="btn btn-ghost btn-icon">
          <ArrowLeft className="w-5 h-5" />
        </button>
        <h1 className="text-2xl font-bold" style={{ color: 'var(--color-text-primary)' }}>
          {isEditing ? 'Editar Persona' : 'Nueva Persona'}
        </h1>
      </div>

      <form onSubmit={handleSubmit} className="flex flex-col gap-6">
        {/* Basic Info */}
        <div className="card p-6 flex flex-col gap-5">
          <h2 className="text-lg font-semibold" style={{ color: 'var(--color-text-primary)' }}>Información Personal</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <div className="flex flex-col gap-1.5">
              <label className="text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Nombres *</label>
              <input required type="text" name="first_name" className="input" value={formData.first_name} onChange={handleChange} placeholder="Ej. Juan" />
            </div>
            
            <div className="flex flex-col gap-1.5">
              <label className="text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Apellidos *</label>
              <input required type="text" name="last_name" className="input" value={formData.last_name} onChange={handleChange} placeholder="Ej. Pérez" />
            </div>

            <div className="flex flex-col gap-1.5">
              <label className="text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Tipo Documento</label>
              <select name="document_type" className="input" value={formData.document_type} onChange={handleChange}>
                <option value="CC">Cédula de Ciudadanía</option>
                <option value="CE">Cédula de Extranjería</option>
                <option value="NIT">NIT</option>
                <option value="PP">Pasaporte</option>
                <option value="TI">Tarjeta de Identidad</option>
                <option value="OTHER">Otro</option>
              </select>
            </div>

            <div className="flex flex-col gap-1.5">
              <label className="text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Número Documento</label>
              <input type="text" name="document_number" className="input" value={formData.document_number} onChange={handleChange} />
            </div>

            <div className="flex flex-col gap-1.5">
              <label className="text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Profesión</label>
              <input type="text" name="profession" className="input" value={formData.profession} onChange={handleChange} placeholder="Ej. Ingeniero de Software" />
            </div>
          </div>
        </div>

        {/* Location Info */}
        <div className="card p-6 flex flex-col gap-5">
          <h2 className="text-lg font-semibold" style={{ color: 'var(--color-text-primary)' }}>Ubicación</h2>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
            <div className="flex flex-col gap-1.5 md:col-span-2">
              <label className="text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Dirección</label>
              <input type="text" name="address" className="input" value={formData.address} onChange={handleChange} placeholder="Ej. Calle 123 #45-67" />
            </div>
            <div className="flex flex-col gap-1.5">
              <label className="text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Ciudad</label>
              <input type="text" name="city" className="input" value={formData.city} onChange={handleChange} />
            </div>
            <div className="flex flex-col gap-1.5">
              <label className="text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>País</label>
              <input type="text" name="country" className="input" value={formData.country} onChange={handleChange} />
            </div>
          </div>
        </div>

        {/* Contacts Info */}
        <div className="card p-6 flex flex-col gap-5">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold" style={{ color: 'var(--color-text-primary)' }}>Contactos (Máximo 3)</h2>
            <button type="button" onClick={addContact} className="btn btn-secondary btn-sm" disabled={(formData.contacts?.length || 0) >= 3}>
              <Plus className="w-4 h-4" />
              Agregar Contacto
            </button>
          </div>
          
          <div className="flex flex-col gap-4">
            {formData.contacts?.map((contact, index) => (
              <div key={index} className="flex gap-3 items-end">
                <div className="flex flex-col gap-1.5 w-1/4">
                  <label className="text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Tipo</label>
                  <select 
                    className="input" 
                    value={contact.contact_type} 
                    onChange={(e) => handleContactChange(index, 'contact_type', e.target.value)}
                  >
                    <option value="phone">Teléfono</option>
                    <option value="whatsapp">WhatsApp</option>
                    <option value="email">Correo</option>
                    <option value="facebook">Facebook</option>
                    <option value="instagram">Instagram</option>
                    <option value="other">Otro</option>
                  </select>
                </div>
                <div className="flex flex-col gap-1.5 flex-1">
                  <label className="text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Valor</label>
                  <input 
                    type="text" 
                    className="input" 
                    value={contact.contact_value} 
                    placeholder="Número o usuario..."
                    onChange={(e) => handleContactChange(index, 'contact_value', e.target.value)} 
                  />
                </div>
                <div className="flex flex-col gap-1.5 w-1/4">
                  <label className="text-sm font-medium" style={{ color: 'var(--color-text-secondary)' }}>Etiqueta</label>
                  <input 
                    type="text" 
                    className="input" 
                    value={contact.label || ''} 
                    placeholder="Ej. Personal"
                    onChange={(e) => handleContactChange(index, 'label', e.target.value)} 
                  />
                </div>
                <button type="button" onClick={() => removeContact(index)} className="btn btn-ghost btn-icon mb-1">
                  <Trash2 className="w-5 h-5" style={{ color: 'var(--color-danger)' }} />
                </button>
              </div>
            ))}
            {(!formData.contacts || formData.contacts.length === 0) && (
              <p className="text-sm" style={{ color: 'var(--color-text-muted)' }}>No hay contactos agregados.</p>
            )}
          </div>
        </div>

        <div className="flex justify-end gap-3 pt-2">
          <button type="button" onClick={() => navigate('/persons')} className="btn btn-ghost" disabled={loading}>
            Cancelar
          </button>
          <button type="submit" className="btn btn-primary" disabled={loading}>
            <Save className="w-4 h-4" />
            {loading ? 'Guardando...' : 'Guardar Registro'}
          </button>
        </div>
      </form>
    </div>
  )
}
