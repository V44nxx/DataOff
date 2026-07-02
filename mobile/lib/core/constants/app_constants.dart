/// DataOff — Constantes globales de la aplicación
class AppConstants {
  AppConstants._();

  // ── API ────────────────────────────────────────────────────
  static const String apiBaseUrl = 'http://192.168.20.25:8000/api/v1'; // Red local Wi-Fi para celular
  static const int apiTimeoutSeconds = 30;
  static const int syncTimeoutSeconds = 60;

  // ── Base de datos local ────────────────────────────────────
  static const String dbName = 'dataoff.db';
  static const int dbVersion = 1;

  // ── Claves de almacenamiento seguro ───────────────────────
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyDeviceId = 'device_id';
  static const String keyUserId = 'user_id';
  static const String keyUserRole = 'user_role';
  static const String keyUserName = 'user_name';

  // ── Sincronización ────────────────────────────────────────
  static const int maxSyncRetries = 3;
  static const int syncBatchSize = 50;     // Registros por lote
  static const int syncIntervalMinutes = 5; // Sync automático cada 5 min

  // ── Paginación ────────────────────────────────────────────
  static const int defaultPageSize = 20;
}

/// Rutas de la aplicación
class AppRoutes {
  AppRoutes._();
  static const String splash   = '/';
  static const String login    = '/login';
  static const String home     = '/home';
  static const String persons  = '/persons';
  static const String personNew  = '/persons/new';
  static const String personDetail = '/persons/:id';
  static const String sync     = '/sync';
  static const String profile  = '/profile';
}
