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

  Future<void> _savePerson() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    final personRepo = getIt<PersonRepository>();
    final personId = const Uuid().v4();
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
      documentNumber: _documentNumberController.text.trim(),
      profession: _professionController.text.trim(),
      address: _addressController.text.trim(),
      city: _cityController.text.trim(),
      country: 'Colombia',
      capturedAt: now,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'pending',
      syncSource: 'mobile',
      contacts: contacts,
    );

    try {
      await personRepo.savePerson(person);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Persona guardada offline con éxito')),
        );
        context.pop();
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _documentNumberController.dispose();
    _professionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    for (var c in _contactValueControllers) c.dispose();
    for (var c in _contactLabelControllers) c.dispose();
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
