import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/injection.dart';
import '../../domain/entities/person.dart';
import '../../domain/repositories/person_repository.dart';

class PersonFormScreen extends StatefulWidget {
  final Person? personToEdit;

  const PersonFormScreen({super.key, this.personToEdit});

  @override
  State<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends State<PersonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _documentNumberController = TextEditingController();
  final _professionController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  String _documentType = 'CC';
  bool _isLoading = false;
  Person? _existingPerson;

  bool get _isEditing => widget.personToEdit != null;

  // ── Regex para Validaciones Estrictas ─────────────────────────
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F600}-\u{1F64F}'
    r'|\u{1F300}-\u{1F5FF}'
    r'|\u{1F680}-\u{1F6FF}'
    r'|\u{1F1E0}-\u{1F1FF}'
    r'|\u{2600}-\u{26FF}'
    r'|\u{2700}-\u{27BF}'
    r'|\u{FE00}-\u{FE0F}'
    r'|\u{1F900}-\u{1F9FF}'
    r'|\u{1FA70}-\u{1FAFF}'
    r'|\u{200D}'
    r']',
    unicode: true,
  );

  static final RegExp _allowLettersRegex = RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]');
  static final RegExp _lettersOnlyRegex = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s]+$');

  bool _containsEmoji(String text) => _emojiRegex.hasMatch(text);

  // Contact fields (Up to 3)
  final List<String> _contactTypes = ['Teléfono', 'Teléfono', 'Teléfono'];
  final List<TextEditingController> _contactValueControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];
  final List<TextEditingController> _contactLabelControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.personToEdit != null) {
      _initFromPerson(widget.personToEdit!);
    } else {
      _documentNumberController.addListener(_onDocumentNumberChanged);
    }
  }

  void _initFromPerson(Person person) {
    _existingPerson = person;
    _firstNameController.text = person.firstName;
    _lastNameController.text = person.lastName;
    _documentType = person.documentType ?? 'CC';
    _documentNumberController.text = person.documentNumber ?? '';
    _professionController.text = person.profession ?? '';
    _addressController.text = person.address ?? '';
    _cityController.text = person.city ?? '';

    for (int i = 0; i < person.contacts.length && i < 3; i++) {
      final c = person.contacts[i];
      _contactTypes[i] = _formatContactType(c.contactType);
      _contactValueControllers[i].text = c.contactValue;
      _contactLabelControllers[i].text = c.label ?? '';
    }
  }

  String _formatContactType(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('what')) return 'WhatsApp';
    if (lower.contains('mail') || lower.contains('correo')) return 'Correo';
    if (lower.contains('face')) return 'Facebook';
    if (lower.contains('insta')) return 'Instagram';
    return 'Teléfono';
  }

  void _onDocumentNumberChanged() async {
    if (_isEditing) return;
    final doc = _documentNumberController.text.trim();
    if (doc.length >= 5) {
      final personRepo = getIt<PersonRepository>();
      final existing = await personRepo.getPersonByDocument(doc);
      if (mounted) {
        setState(() {
          _existingPerson = existing;
          if (existing != null) {
            if (_firstNameController.text.isEmpty) {
              _firstNameController.text = existing.firstName;
            }
            if (_lastNameController.text.isEmpty) {
              _lastNameController.text = existing.lastName;
            }
            if (_professionController.text.isEmpty && (existing.profession?.isNotEmpty ?? false)) {
              _professionController.text = existing.profession!;
            }
            if (_addressController.text.isEmpty && (existing.address?.isNotEmpty ?? false)) {
              _addressController.text = existing.address!;
            }
            if (_cityController.text.isEmpty && (existing.city?.isNotEmpty ?? false)) {
              _cityController.text = existing.city!;
            }
          }
        });
      }
    } else if (_existingPerson != null) {
      setState(() => _existingPerson = null);
    }
  }

  Future<void> _savePerson() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final personRepo = getIt<PersonRepository>();
    final docNumber = _documentNumberController.text.trim();

    Person? existing = _existingPerson;
    if (existing == null && docNumber.isNotEmpty) {
      existing = await personRepo.getPersonByDocument(docNumber);
    }

    final personId = widget.personToEdit?.id ?? existing?.id ?? const Uuid().v4();
    final now = DateTime.now().toUtc();

    // Crear lista de contactos validados
    List<Contact> contacts = [];
    for (int i = 0; i < 3; i++) {
      final val = _contactValueControllers[i].text.trim();
      final label = _contactLabelControllers[i].text.trim();
      if (val.isNotEmpty) {
        contacts.add(Contact(
          id: const Uuid().v4(),
          personId: personId,
          contactType: _contactTypes[i],
          contactValue: val,
          label: label.isNotEmpty ? label : null,
          capturedAt: now,
          createdAt: now,
          updatedAt: now,
        ));
      }
    }

    final person = Person(
      id: personId,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      documentType: _documentType,
      documentNumber: docNumber.isNotEmpty ? docNumber : null,
      profession: _professionController.text.trim().isNotEmpty ? _professionController.text.trim() : null,
      address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
      city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
      country: 'Colombia',
      capturedAt: existing?.capturedAt ?? widget.personToEdit?.capturedAt ?? now,
      createdAt: existing?.createdAt ?? widget.personToEdit?.createdAt ?? now,
      updatedAt: now,
      syncStatus: 'pending',
      syncSource: 'mobile',
      contacts: contacts,
    );

    try {
      await personRepo.savePerson(person);
      if (mounted) {
        String msg = _isEditing ? 'Persona actualizada con éxito' : 'Persona guardada offline con éxito';
        if (!_isEditing && existing != null) {
          final existingPhones = existing.contacts.map((c) => c.contactValue.toLowerCase().trim()).toSet();
          final newCount = contacts.where((c) => !existingPhones.contains(c.contactValue.toLowerCase().trim())).length;
          if (newCount > 0) {
            msg = 'Cédula actualizada: $newCount nuevo(s) contacto(s) en Puesto 1 (orden de escalera)';
          } else {
            msg = 'Cédula actualizada con éxito (los números ya estaban registrados)';
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: _isEditing || existing != null ? Colors.teal.shade700 : Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    if (!_isEditing) {
      _documentNumberController.removeListener(_onDocumentNumberChanged);
    }
    _firstNameController.dispose();
    _lastNameController.dispose();
    _documentNumberController.dispose();
    _professionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    for (var c in _contactValueControllers) {
      c.dispose();
    }
    for (var c in _contactLabelControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _buildContactSection(int index) {
    final isPhone = _contactTypes[index] == 'Teléfono' || _contactTypes[index] == 'WhatsApp';
    final isEmail = _contactTypes[index] == 'Correo';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isPhone ? Icons.phone_android : (isEmail ? Icons.email_outlined : Icons.tag),
                  size: 16,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  index == 0
                      ? 'Contacto 1 (Puesto 1 - Principal / Reciente)'
                      : 'Contacto ${index + 1} (Puesto ${index + 1})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (isPhone)
                  const Text(' (10 dígitos)', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _contactTypes[index],
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Teléfono', child: Text('Teléfono')),
                      DropdownMenuItem(value: 'WhatsApp', child: Text('WhatsApp')),
                      DropdownMenuItem(value: 'Correo', child: Text('Correo')),
                      DropdownMenuItem(value: 'Instagram', child: Text('Instagram')),
                      DropdownMenuItem(value: 'Facebook', child: Text('Facebook')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _contactTypes[index] = val;
                          _contactValueControllers[index].clear();
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _contactValueControllers[index],
                    decoration: InputDecoration(
                      labelText: isPhone ? 'Número (10 dígitos)' : (isEmail ? 'Correo electrónico' : 'Usuario / Enlace'),
                      hintText: isPhone ? 'Ej: 3001234567' : null,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    keyboardType: isPhone ? TextInputType.number : (isEmail ? TextInputType.emailAddress : TextInputType.text),
                    inputFormatters: isPhone
                        ? [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ]
                        : [
                            FilteringTextInputFormatter.deny(_emojiRegex),
                          ],
                    validator: (v) {
                      final val = v?.trim() ?? '';
                      if (val.isEmpty) return null;
                      if (_containsEmoji(val)) return 'No se permiten emojis';
                      if (isPhone) {
                        if (!RegExp(r'^\d+$').hasMatch(val)) return 'Solo números';
                        if (val.length != 10) return 'Debe tener exactamente 10 dígitos';
                      } else if (isEmail) {
                        if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(val)) return 'Correo inválido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactLabelControllers[index],
              decoration: const InputDecoration(
                labelText: 'Etiqueta opcional (Ej: Personal, Trabajo)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.deny(_emojiRegex),
              ],
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isNotEmpty && _containsEmoji(val)) return 'No se permiten emojis';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Persona' : 'Nueva Persona (Offline)'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isEditing ? 'Editar Información Personal' : 'Datos Personales',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Nombres
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombres *',
                        hintText: 'Solo letras, sin números ni emojis',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(_allowLettersRegex),
                        FilteringTextInputFormatter.deny(_emojiRegex),
                      ],
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isEmpty) return 'El nombre es requerido';
                        if (_containsEmoji(val)) return 'No se permiten emojis';
                        if (RegExp(r'[0-9]').hasMatch(val)) return 'No se permiten números en nombres';
                        if (!_lettersOnlyRegex.hasMatch(val)) return 'Solo se permiten letras';
                        if (val.length < 2) return 'Mínimo 2 letras';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Apellidos
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Apellidos *',
                        hintText: 'Solo letras, sin números ni emojis',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(_allowLettersRegex),
                        FilteringTextInputFormatter.deny(_emojiRegex),
                      ],
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isEmpty) return 'El apellido es requerido';
                        if (_containsEmoji(val)) return 'No se permiten emojis';
                        if (RegExp(r'[0-9]').hasMatch(val)) return 'No se permiten números en apellidos';
                        if (!_lettersOnlyRegex.hasMatch(val)) return 'Solo se permiten letras';
                        if (val.length < 2) return 'Mínimo 2 letras';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Documento
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: _documentType,
                            decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'CC', child: Text('CC')),
                              DropdownMenuItem(value: 'CE', child: Text('CE')),
                              DropdownMenuItem(value: 'NIT', child: Text('NIT')),
                              DropdownMenuItem(value: 'PP', child: Text('PP')),
                              DropdownMenuItem(value: 'TI', child: Text('TI')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _documentType = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _documentNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Número de Documento',
                              hintText: 'Solo números',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.pin_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(15),
                              FilteringTextInputFormatter.deny(_emojiRegex),
                            ],
                            validator: (v) {
                              final val = v?.trim() ?? '';
                              if (val.isEmpty) return null;
                              if (_containsEmoji(val)) return 'No se permiten emojis';
                              if (!RegExp(r'^\d+$').hasMatch(val)) return 'Solo se permiten números';
                              if (val.length < 5) return 'Mínimo 5 dígitos';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    if (!_isEditing && _existingPerson != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Persona registrada: ${_existingPerson!.fullName}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Teléfonos actuales: ${_existingPerson!.contacts.isEmpty ? "Sin teléfonos previos" : _existingPerson!.contacts.map((c) => "${c.label ?? "Contacto"}: ${c.contactValue}").join(", ")}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Regla de escalera (máx 3): Cada número nuevo tomará el Puesto 1 (Contacto 1) y desplazará los anteriores hacia el 2 y 3.',
                              style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Profesión
                    TextFormField(
                      controller: _professionController,
                      decoration: const InputDecoration(
                        labelText: 'Profesión',
                        hintText: 'Solo letras y puntuación, sin números ni emojis',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s\.\,\-]')),
                        FilteringTextInputFormatter.deny(_emojiRegex),
                      ],
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isNotEmpty) {
                          if (_containsEmoji(val)) return 'No se permiten emojis';
                          if (RegExp(r'[0-9]').hasMatch(val)) return 'No se permiten números en la profesión';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Dirección
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        hintText: 'Ej: Calle 123 #45-67',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(_emojiRegex),
                      ],
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isNotEmpty && _containsEmoji(val)) return 'No se permiten emojis';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Ciudad
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'Ciudad',
                        hintText: 'Solo letras, sin números ni emojis',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(_allowLettersRegex),
                        FilteringTextInputFormatter.deny(_emojiRegex),
                      ],
                      validator: (v) {
                        final val = v?.trim() ?? '';
                        if (val.isNotEmpty) {
                          if (_containsEmoji(val)) return 'No se permiten emojis';
                          if (RegExp(r'[0-9]').hasMatch(val)) return 'No se permiten números en la ciudad';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),
                    const Row(
                      children: [
                        Icon(Icons.contacts_outlined, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text('Contactos (Máx 3, solo números de 10 dígitos)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildContactSection(0),
                    _buildContactSection(1),
                    _buildContactSection(2),

                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _savePerson,
                      icon: Icon(_isEditing ? Icons.save_rounded : Icons.check_circle_rounded),
                      label: Text(
                        _isEditing ? 'Guardar Cambios' : 'Guardar Registro Offline',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: _isEditing ? Colors.teal.shade700 : Colors.blueAccent.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
