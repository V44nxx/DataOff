import 'package:sqflite/sqflite.dart';

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
  Future<void> savePerson(Person person) async {
    final db = await _db;
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
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
}
