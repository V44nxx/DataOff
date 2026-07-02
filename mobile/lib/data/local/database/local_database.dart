import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../../../core/constants/app_constants.dart';

/// DataOff — Base de datos SQLite local
/// Espejo del esquema PostgreSQL del backend.
/// Incluye sync_status para la cola de sincronización.
class LocalDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _initDatabase();
    return _db!;
  }

  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// ── Creación del esquema ─────────────────────────────────
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE persons (
        id            TEXT PRIMARY KEY,
        user_id       TEXT,
        first_name    TEXT NOT NULL,
        last_name     TEXT NOT NULL,
        document_type TEXT,
        document_number TEXT,
        birth_date    TEXT,
        gender        TEXT,
        address       TEXT,
        city          TEXT,
        department    TEXT,
        country       TEXT DEFAULT 'Colombia',
        profession    TEXT,
        notes         TEXT,
        captured_at   TEXT NOT NULL,
        synced_at     TEXT,
        sync_source   TEXT DEFAULT 'mobile',
        sync_status   TEXT DEFAULT 'pending',
        device_id     TEXT,
        is_deleted    INTEGER DEFAULT 0,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE contacts (
        id            TEXT PRIMARY KEY,
        person_id     TEXT NOT NULL,
        contact_type  TEXT NOT NULL,
        contact_value TEXT NOT NULL,
        is_primary    INTEGER DEFAULT 0,
        label         TEXT,
        captured_at   TEXT NOT NULL,
        synced_at     TEXT,
        sync_source   TEXT DEFAULT 'mobile',
        is_deleted    INTEGER DEFAULT 0,
        created_at    TEXT NOT NULL,
        updated_at    TEXT NOT NULL,
        FOREIGN KEY (person_id) REFERENCES persons(id) ON DELETE CASCADE
      )
    ''');

    // Cola de sincronización
    await db.execute('''
      CREATE TABLE sync_queue (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id   TEXT NOT NULL,
        operation   TEXT NOT NULL,
        payload     TEXT NOT NULL,
        created_at  TEXT NOT NULL,
        attempts    INTEGER DEFAULT 0,
        last_attempt TEXT,
        status      TEXT DEFAULT 'pending'
      )
    ''');

    // Índices para rendimiento
    await db.execute('CREATE INDEX idx_persons_sync_status ON persons(sync_status)');
    await db.execute('CREATE INDEX idx_persons_captured_at ON persons(captured_at)');
    await db.execute('CREATE INDEX idx_contacts_person_id ON contacts(person_id)');
    await db.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(status)');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migraciones futuras aquí
  }

  /// Cierra la base de datos
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
