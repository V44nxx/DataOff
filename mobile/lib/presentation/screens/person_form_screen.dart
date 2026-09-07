import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/injection.dart';
import '../../domain/entities/person.dart';
import '../../domain/repositories/person_repository.dart';

class PersonFormScreen extends StatefulWidget {
  const PersonFormScreen({super.key});

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
    _documentNumberController.addListener(_onDocumentNumberChanged);
  }

  void _onDocumentNumberChanged() async {
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
    Person? existing;
    if (docNumber.isNotEmpty) {
      existing = await personRepo.getPersonByDocument(docNumber);
    }

    final personId = existing?.id ?? const Uuid().v4();
    final now = DateTime.now().toUtc();

    // Create contacts list
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
      documentNumber: docNumber,
      profession: _professionController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      country: 'Colombia',
      capturedAt: existing?.capturedAt ?? now,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      syncStatus: 'pending',
      syncSource: 'mobile',
      contacts: contacts,
    );

    try {
      await personRepo.savePerson(person);
      if (mounted) {
        String msg = 'Persona guardada offline con éxito';
        if (existing != null) {
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
            backgroundColor: existing != null ? Colors.teal.shade700 : Colors.green.shade700,
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
    _documentNumberController.removeListener(_onDocumentNumberChanged);
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contacto ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _contactTypes[index],
                    decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'Teléfono', child: Text('Teléfono')),
                      DropdownMenuItem(value: 'WhatsApp', child: Text('WhatsApp')),
                      DropdownMenuItem(value: 'Correo', child: Text('Correo')),
                      DropdownMenuItem(value: 'Instagram', child: Text('Instagram')),
                      DropdownMenuItem(value: 'Facebook', child: Text('Facebook')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _contactTypes[index] = val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _contactValueControllers[index],
                    decoration: const InputDecoration(labelText: 'Valor (Ej: 300...)', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactLabelControllers[index],
              decoration: const InputDecoration(labelText: 'Etiqueta opcional (Ej: Trabajo, Personal)', border: OutlineInputBorder()),
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
        title: const Text('Nueva Persona (Offline)'),
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
                  const Text('Datos Personales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(labelText: 'Nombres *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(labelText: 'Apellidos *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _documentType,
                          decoration: const InputDecoration(labelText: 'Documento', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'CC', child: Text('CC')),
                            DropdownMenuItem(value: 'CE', child: Text('CE')),
                            DropdownMenuItem(value: 'NIT', child: Text('NIT')),
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
                          decoration: const InputDecoration(labelText: 'Número de Documento', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  if (_existingPerson != null) ...[
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
                            'Regla de escalera (máx 3): Cada número nuevo tomará el Puesto 1 (Contacto 1) y desplazará los anteriores hacia el 2 y 3. Si se supera el límite de 3, el más antiguo se descartará.',
                            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _professionController,
                    decoration: const InputDecoration(labelText: 'Profesión', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(labelText: 'Ciudad', border: OutlineInputBorder()),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text('Contactos (Opcional)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  _buildContactSection(0),
                  _buildContactSection(1),
                  _buildContactSection(2),

                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _savePerson,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Guardar Registro Offline', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
    );
  }
}
