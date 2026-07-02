import 'package:uuid/uuid.dart';

import '../entities/person.dart';
import '../repositories/person_repository.dart';
import '../repositories/auth_repository.dart';

const _uuid = Uuid();

/// UC: Obtener todas las personas (ordenadas por captured_at DESC)
class GetPersonsUseCase {
  final PersonRepository _repository;
  GetPersonsUseCase(this._repository);

  Future<List<Person>> call({String? query}) async {
    final persons = query != null && query.isNotEmpty
        ? await _repository.searchPersons(query)
        : await _repository.getPersonsWithContacts();

    // Siempre ordenar por captured_at DESC (fecha real de captura)
    persons.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return persons;
  }
}

/// UC: Crear una persona nueva (offline-first)
/// 1. Genera UUID en el dispositivo
/// 2. Guarda localmente con sync_status='pending'
/// 3. La sincronización ocurre en background
class CreatePersonUseCase {
  final PersonRepository _personRepo;
  final AuthRepository _authRepo;

  CreatePersonUseCase(this._personRepo, this._authRepo);

  Future<Person> call({
    required String firstName,
    required String lastName,
    String? documentType,
    String? documentNumber,
    DateTime? birthDate,
    String? gender,
    String? address,
    String? city,
    String? department,
    String country = 'Colombia',
    String? notes,
    List<Contact> contacts = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final deviceId = await _authRepo.getAccessToken();
    final userId = (await _authRepo.getCurrentUser())?.id;

    // UUID generado localmente — crítico para offline-first
    final person = Person(
      id: _uuid.v4(),
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      documentType: documentType,
      documentNumber: documentNumber,
      birthDate: birthDate,
      gender: gender,
      address: address,
      city: city,
      department: department,
      country: country,
      notes: notes,
      capturedAt: now,   // ← Fecha real de captura. INMUTABLE.
      syncSource: 'mobile',
      syncStatus: 'pending',  // ← Pendiente hasta que se sincronice
      contacts: contacts,
      createdAt: now,
      updatedAt: now,
    );

    await _personRepo.savePerson(person);
    return person;
  }
}

/// UC: Actualizar una persona existente
class UpdatePersonUseCase {
  final PersonRepository _repository;
  UpdatePersonUseCase(this._repository);

  Future<Person> call(Person original, Map<String, dynamic> changes) async {
    final now = DateTime.now().toUtc();

    // Aplicar la misma regla del Merge Engine: nunca vacíos
    Person updated = original.copyWith(
      firstName: _nonEmpty(changes['firstName'], original.firstName),
      lastName: _nonEmpty(changes['lastName'], original.lastName),
      documentType: changes['documentType'] as String? ?? original.documentType,
      documentNumber: _nonEmpty(changes['documentNumber'], original.documentNumber),
      address: changes['address'] as String? ?? original.address,
      city: _nonEmpty(changes['city'], original.city),
      notes: changes['notes'] as String? ?? original.notes,
      syncStatus: 'pending',  // Vuelve a pending para re-sincronizar
      updatedAt: now,
    );

    await _repository.savePerson(updated);
    return updated;
  }

  String? _nonEmpty(dynamic value, String? fallback) {
    if (value == null || (value is String && value.trim().isEmpty)) return fallback;
    return value as String;
  }
}

/// UC: Contar registros pendientes de sincronización
class CountPendingUseCase {
  final PersonRepository _repository;
  CountPendingUseCase(this._repository);

  Future<int> call() => _repository.countPending();
}
