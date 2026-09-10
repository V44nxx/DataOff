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

    // 1. Verificar si ya existe una persona (por ID primero para edición, o por cédula)
    Person? existing;
    if (person.id.isNotEmpty) {
      existing = await getPersonById(person.id);
    }
    if (existing == null && person.documentNumber != null && person.documentNumber!.trim().isNotEmpty) {
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
          'document_number': person.documentNumber ?? existing.documentNumber,
          'profession': person.profession,
          'address': person.address,
          'city': person.city,
          'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [targetId],
      );

      // Actualizar tipos o etiquetas de contactos existentes si cambiaron
      for (final c in person.contacts) {
        final val = c.contactValue.trim();
        if (val.isNotEmpty) {
          await db.update(
            'contacts',
            {
              'contact_type': c.contactType,
              'label': c.label,
              'updated_at': now,
            },
            where: 'person_id = ? AND LOWER(contact_value) = ?',
            whereArgs: [targetId, val.toLowerCase()],
          );
        }
      }

      // Contactos activos actuales ordenados de Contacto 1 a Contacto 3
      final activeContacts = List<Contact>.from(existing.contacts);

      final existingValues = activeContacts
          .map((c) => c.contactValue.trim().toLowerCase())
          .toSet();

      // Identificar números nuevos a agregar (que sean diferentes a los ya existentes)
      final incomingNew = <Contact>[];
      for (final newC in person.contacts) {
        final val = newC.contactValue.trim();
        if (val.isNotEmpty && !existingValues.contains(val.toLowerCase())) {
          incomingNew.add(newC);
          existingValues.add(val.toLowerCase());
        }
      }

      if (incomingNew.isNotEmpty) {
        // Enfoque Escalera (Máximo 3 contactos):
        // El nuevo contacto toma el Puesto 1 (Contacto 1).
        // El que estaba en Puesto 1 pasa al Puesto 2 (Contacto 2).
        // El que estaba en Puesto 2 pasa al Puesto 3 (Contacto 3).
        // El que estaba en Puesto 3 (o el más antiguo) se descarta.
        final List<Contact> shiftedList = [];

        // Insertar los nuevos al inicio (toman puesto 1)
        for (int i = incomingNew.length - 1; i >= 0; i--) {
          final c = incomingNew[i];
          final contactId = const Uuid().v4();
          final capTime = DateTime.now().toUtc();
          shiftedList.insert(
            0,
            c.copyWith(
              id: contactId,
              personId: targetId,
              syncSource: 'mobile',
              capturedAt: capTime,
              createdAt: capTime,
              updatedAt: capTime,
            ),
          );
        }

        // Añadir los contactos previos detrás
        shiftedList.addAll(activeContacts);

        // Conservar solo máximo 3
        final toKeep = shiftedList.take(3).toList();
        final toEvict = shiftedList.skip(3).toList();

        // 1. Desactivar los que superaron el límite de 3
        for (final ev in toEvict) {
          await db.update(
            'contacts',
            {
              'is_deleted': 1,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [ev.id],
          );
        }

        // 2. Guardar o actualizar los 3 contactos con sus etiquetas de escalera
        for (int i = 0; i < toKeep.length; i++) {
          final c = toKeep[i];
          final label = 'Contacto ${i + 1}';
          final isPrimary = (i == 0);

          final updatedContact = c.copyWith(
            label: label,
            isPrimary: isPrimary,
            personId: targetId,
            resetSyncedAt: true,
            updatedAt: DateTime.now().toUtc(),
          );

          await db.insert(
            'contacts',
            ContactModel.toMap(updatedContact),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      final updatedPerson = await getPersonById(targetId);
      if (updatedPerson != null) {
        await _addToSyncQueue(db, updatedPerson);
      }
    } else {
      // ── MODO INSERCIÓN NUEVA (MÁXIMO 3 CONTACTOS) ───────────
      await db.insert(
        'persons',
        PersonModel.toMap(person),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Guardar contactos (máximo 3, etiquetados como Contacto 1, 2, 3)
      final distinctContacts = <Contact>[];
      final seenValues = <String>{};
      for (final c in person.contacts) {
        final val = c.contactValue.trim();
        if (val.isNotEmpty && !seenValues.contains(val.toLowerCase())) {
          distinctContacts.add(c);
          seenValues.add(val.toLowerCase());
        }
      }

      final contactsToSave = distinctContacts.take(3).toList();
      for (int i = 0; i < contactsToSave.length; i++) {
        final c = contactsToSave[i];
        final label = 'Contacto ${i + 1}';
        final isPrimary = (i == 0);

        final contactToInsert = c.copyWith(
          label: label,
          isPrimary: isPrimary,
          personId: person.id,
        );

        await db.insert(
          'contacts',
          ContactModel.toMap(contactToInsert),
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
    final maps = await db.rawQuery('''
      SELECT DISTINCT p.* FROM persons p
      LEFT JOIN contacts c ON c.person_id = p.id
      WHERE p.is_deleted = 0 AND (
        p.sync_status != 'synced' OR
        c.synced_at IS NULL
      )
      ORDER BY p.captured_at ASC
    ''');
    return _personsWithContacts(db, maps);
  }

  @override
  Future<List<Person>> getPersonsWithContacts() async {
    return getAllPersons();
  }

  @override
  Future<int> countPending() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT COUNT(DISTINCT p.id) as count FROM persons p
      LEFT JOIN contacts c ON c.person_id = p.id
      WHERE p.is_deleted = 0 AND (
        p.sync_status != 'synced' OR
        c.synced_at IS NULL
      )
    ''');
    return (result.first['count'] as int?) ?? 0;
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

  Future<void> markContactSynced(String contactId) async {
    final db = await _db;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'contacts',
      {'synced_at': now},
      where: 'id = ?',
      whereArgs: [contactId],
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
      orderBy: 'label ASC, captured_at DESC', // Contacto 1 primero, máx 3
      limit: 3,
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
