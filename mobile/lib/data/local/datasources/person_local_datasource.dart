import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/person.dart';
import '../../../domain/repositories/person_repository.dart';
import '../database/local_database.dart';
import '../models/person_model.dart';

/// Implementación SQLite del PersonRepository
/// Esta clase es la única que sabe de sqflite.
class PersonLocalDataSource implements PersonRepository {

  Future<Database> get _db async => LocalDatabase.instance;

  @override
  Future<List<Person>> getAllPersons() async {
    final db = await _db;
    final maps = await db.query(
      'persons',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'captured_at DESC',  // ← Siempre por fecha real de captura
    );
    return _personsWithContacts(db, maps);
  }

  @override
  Future<List<Person>> searchPersons(String query) async {
    final db = await _db;
    final term = '%${query.toLowerCase()}%';
    final maps = await db.query(
      'persons',
      where: '''
        is_deleted = 0 AND (
          LOWER(first_name) LIKE ? OR
          LOWER(last_name) LIKE ? OR
          document_number LIKE ?
        )
      ''',
      whereArgs: [term, term, term],
      orderBy: 'captured_at DESC',
    );
    return _personsWithContacts(db, maps);
  }

  @override
  Future<Person?> getPersonById(String id) async {
    final db = await _db;
    final maps = await db.query(
      'persons',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _personWithContacts(db, maps.first);
  }

  @override
  Future<Person?> getPersonByDocument(String documentNumber) async {
    final doc = documentNumber.trim();
    if (doc.isEmpty) return null;
    final db = await _db;
    final maps = await db.query(
      'persons',
      where: 'document_number = ? AND is_deleted = 0',
      whereArgs: [doc],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return _personWithContacts(db, maps.first);
  }

  @override
  Future<void> savePerson(Person person) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();

    // 1. Verificar si ya existe una persona con este mismo número de documento
    Person? existing;
    if (person.documentNumber != null && person.documentNumber!.trim().isNotEmpty) {
      existing = await getPersonByDocument(person.documentNumber!);
    }

    if (existing != null) {
      // ── MODO ACTUALIZACIÓN Y FUSIÓN DE CONTACTOS ─────────────
      final targetId = existing.id;

      // Actualizar datos de la persona
      await db.update(
        'persons',
        {
          'first_name': person.firstName.isNotEmpty ? person.firstName : existing.firstName,
          'last_name': person.lastName.isNotEmpty ? person.lastName : existing.lastName,
          'document_type': person.documentType ?? existing.documentType,
          'profession': (person.profession?.isNotEmpty ?? false) ? person.profession : existing.profession,
          'address': (person.address?.isNotEmpty ?? false) ? person.address : existing.address,
          'city': (person.city?.isNotEmpty ?? false) ? person.city : existing.city,
          'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [targetId],
      );

      // Contactos existentes (para evitar duplicar números)
      final existingValues = existing.contacts
          .map((c) => c.contactValue.trim().toLowerCase())
          .toSet();

      // Guardar números nuevos que sean diferentes (Contacto 2, Contacto 3, etc.)
      int contactCount = existing.contacts.length;
      for (final newContact in person.contacts) {
        final val = newContact.contactValue.trim();
        if (val.isNotEmpty && !existingValues.contains(val.toLowerCase())) {
          contactCount++;
          final label = (newContact.label != null && newContact.label!.trim().isNotEmpty)
              ? newContact.label!.trim()
              : 'Contacto $contactCount';

          final contactToInsert = newContact.copyWith(
            id: const Uuid().v4(),
            personId: targetId,
            label: label,
            syncSource: 'mobile',
            capturedAt: person.capturedAt,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          );
          await db.insert(
            'contacts',
            ContactModel.toMap(contactToInsert),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          existingValues.add(val.toLowerCase());
        }
      }

      final updatedPerson = await getPersonById(targetId);
      if (updatedPerson != null) {
        await _addToSyncQueue(db, updatedPerson);
      }
    } else {
      // ── MODO INSERCIÓN NUEVA ────────────────────────────────
      await db.insert(
        'persons',
        PersonModel.toMap(person),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Guardar contactos
      for (final contact in person.contacts) {
        await db.insert(
          'contacts',
          ContactModel.toMap(contact),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Agregar a la cola de sincronización si es offline
      await _addToSyncQueue(db, person);
    }
  }

  @override
  Future<void> deletePerson(String id) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'persons',
      {'is_deleted': 1, 'updated_at': now, 'sync_status': 'pending'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Person>> getPendingPersons() async {
    final db = await _db;
    final maps = await db.query(
      'persons',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'captured_at ASC',  // Enviar del más antiguo al más nuevo
    );
    return _personsWithContacts(db, maps);
  }

  @override
  Future<List<Person>> getPersonsWithContacts() async {
    return getAllPersons();
  }

  @override
  Future<int> countPending() async {
    final db = await _db;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM persons WHERE sync_status = 'pending'",
    );
    return result.first['count'] as int;
  }

  // ── Marcar como sincronizado ─────────────────────────────
  Future<void> markAsSynced(String id) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'persons',
      {'sync_status': 'synced', 'synced_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAsFailed(String id) async {
    final db = await _db;
    await db.update(
      'persons',
      {'sync_status': 'failed'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── Helpers privados ─────────────────────────────────────
  Future<List<Person>> _personsWithContacts(
      Database db, List<Map<String, dynamic>> maps) async {
    final result = <Person>[];
    for (final map in maps) {
      result.add(await _personWithContacts(db, map));
    }
    return result;
  }

  Future<Person> _personWithContacts(
      Database db, Map<String, dynamic> map) async {
    final personId = map['id'] as String;
    final contactMaps = await db.query(
      'contacts',
      where: 'person_id = ? AND is_deleted = 0',
      whereArgs: [personId],
      orderBy: 'captured_at ASC',  // Contactos ordenados por captura
    );
    final contacts = contactMaps.map(ContactModel.fromMap).toList();
    return PersonModel.fromMap(map, contacts: contacts);
  }

  Future<void> _addToSyncQueue(Database db, Person person) async {
    await db.insert(
      'sync_queue',
      {
        'entity_type': 'person',
        'entity_id': person.id,
        'operation': 'create',
        'payload': '',  // Se serializa al momento de enviar
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
