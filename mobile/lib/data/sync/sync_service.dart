import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/person.dart';
import '../local/datasources/person_local_datasource.dart';
import '../remote/api_client.dart';

/// DataOff — Resultado de sincronización
class SyncResult {
  final int sent;
  final int inserted;
  final int updated;
  final int skipped;
  final int failed;
  final int conflictsResolved;
  final String status;   // 'success' | 'partial' | 'failed'
  final String? error;

  const SyncResult({
    this.sent = 0,
    this.inserted = 0,
    this.updated = 0,
    this.skipped = 0,
    this.failed = 0,
    this.conflictsResolved = 0,
    this.status = 'success',
    this.error,
  });

  bool get isSuccess => status == 'success';
  int get totalProcessed => inserted + updated + skipped;
}

/// DataOff — Servicio de Sincronización Offline-First
///
/// Responsabilidades:
/// 1. Detectar conexión (connectivity_plus)
/// 2. Obtener registros pendientes de SQLite
/// 3. Enviarlos al servidor en lotes via POST /api/v1/sync/push
/// 4. Actualizar sync_status según la respuesta
/// 5. Registrar resultado del sync
class SyncService {
  final PersonLocalDataSource _personDS;
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final Logger _log;

  // Stream para que la UI observe cambios de estado
  final _connectivity = Connectivity();

  SyncService({
    required PersonLocalDataSource personDataSource,
  })  : _personDS = personDataSource,
        _dio = ApiClient.instance.dio,
        _storage = const FlutterSecureStorage(),
        _log = Logger(printer: PrettyPrinter(methodCount: 0));

  // ── Verificar conectividad ────────────────────────────────
  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return result.any((r) =>
        r == ConnectivityResult.mobile || r == ConnectivityResult.wifi);
  }

  /// Stream de cambios de conectividad
  Stream<bool> get connectivityStream => _connectivity.onConnectivityChanged.map(
    (results) => results.any((r) =>
        r == ConnectivityResult.mobile || r == ConnectivityResult.wifi),
  );

  // ── Sincronización principal ──────────────────────────────
  /// Sincroniza todos los registros pendientes con el servidor.
  /// Retorna el resultado detallado de la operación.
  Future<SyncResult> syncPendingRecords() async {
    if (!await isOnline) {
      _log.w('SyncService: Sin conexión. Sync omitido.');
      return const SyncResult(status: 'failed', error: 'Sin conexión a internet');
    }

    final deviceId = await _storage.read(key: AppConstants.keyDeviceId) ?? 'flutter-device';

    // 1. Obtener registros pendientes
    final pendingPersons = await _personDS.getPendingPersons();

    if (pendingPersons.isEmpty) {
      _log.i('SyncService: Sin registros pendientes.');
      return const SyncResult(status: 'success');
    }

    _log.i('SyncService: Sincronizando ${pendingPersons.length} persona(s) pendiente(s)');

    // 2. Construir payload por lotes
    final records = <Map<String, dynamic>>[];

    for (final person in pendingPersons) {
      records.add({
        'entity_type': 'person',
        'operation': person.isDeleted ? 'delete' : 'create',
        'data': _personToPayload(person),
      });

      // Agregar contactos pendientes de esta persona
      for (final contact in person.contacts) {
        if (contact.syncSource == 'mobile') {
          records.add({
            'entity_type': 'contact',
            'operation': contact.isDeleted ? 'delete' : 'create',
            'data': _contactToPayload(contact),
          });
        }
      }
    }

    // 3. Enviar en lotes si hay muchos registros
    final batches = _splitIntoBatches(records, AppConstants.syncBatchSize);
    int totalInserted = 0, totalUpdated = 0, totalSkipped = 0,
        totalFailed = 0, totalConflicts = 0;

    for (final batch in batches) {
      try {
        final response = await _dio.post(
          '/sync/push',
          data: {
            'device_id': deviceId,
            'records': batch,
            'client_timestamp': DateTime.now().toUtc().toIso8601String(),
          },
          options: Options(
            receiveTimeout: const Duration(seconds: AppConstants.syncTimeoutSeconds),
          ),
        );

        final data = response.data as Map<String, dynamic>;
        totalInserted += (data['records_inserted'] as int? ?? 0);
        totalUpdated  += (data['records_updated'] as int? ?? 0);
        totalSkipped  += (data['records_skipped'] as int? ?? 0);
        totalConflicts += (data['conflicts_resolved'] as int? ?? 0);

        // 4. Actualizar sync_status de registros enviados en este lote
        await _markBatchAsSynced(batch, data['results'] as List? ?? []);

      } on DioException catch (e) {
        _log.e('SyncService: Error en lote: ${e.message}');
        totalFailed += batch.length;

        // Marcar como fallidos para reintentar
        for (final record in batch) {
          final entityId = (record['data'] as Map)['id'] as String?;
          if (entityId != null && record['entity_type'] == 'person') {
            await _personDS.markAsFailed(entityId);
          }
        }
      }
    }

    final result = SyncResult(
      sent: records.length,
      inserted: totalInserted,
      updated: totalUpdated,
      skipped: totalSkipped,
      failed: totalFailed,
      conflictsResolved: totalConflicts,
      status: totalFailed == 0 ? 'success' : (totalInserted + totalUpdated > 0 ? 'partial' : 'failed'),
    );

    _log.i('SyncService completado: ${result.status} '
        '(inserted=${result.inserted}, updated=${result.updated}, '
        'conflicts=${result.conflictsResolved})');

    return result;
  }

  // ── Helpers de serialización ──────────────────────────────
  Map<String, dynamic> _personToPayload(Person person) {
    return {
      'id': person.id,
      'user_id': person.userId,
      'first_name': person.firstName,
      'last_name': person.lastName,
      'document_type': person.documentType,
      'document_number': person.documentNumber,
      'birth_date': person.birthDate?.toIso8601String(),
      'gender': person.gender,
      'address': person.address,
      'city': person.city,
      'department': person.department,
      'country': person.country,
      'notes': person.notes,
      'captured_at': person.capturedAt.toIso8601String(),  // ← CRÍTICO
      'updated_at': person.updatedAt.toIso8601String(),
      'sync_source': 'mobile',
    };
  }

  Map<String, dynamic> _contactToPayload(Contact contact) {
    return {
      'id': contact.id,
      'person_id': contact.personId,
      'contact_type': contact.contactType,
      'contact_value': contact.contactValue,
      'is_primary': contact.isPrimary,
      'label': contact.label,
      'captured_at': contact.capturedAt.toIso8601String(),
      'updated_at': contact.updatedAt.toIso8601String(),
      'sync_source': 'mobile',
    };
  }

  List<List<T>> _splitIntoBatches<T>(List<T> list, int batchSize) {
    final batches = <List<T>>[];
    for (var i = 0; i < list.length; i += batchSize) {
      batches.add(list.sublist(i, i + batchSize > list.length ? list.length : i + batchSize));
    }
    return batches;
  }

  Future<void> _markBatchAsSynced(
    List<Map<String, dynamic>> batch,
    List<dynamic> results,
  ) async {
    // Crear mapa de resultados por entity_id
    final resultMap = <String, String>{};
    for (final r in results) {
      final entityId = r['entity_id'] as String?;
      final status = r['status'] as String?;
      if (entityId != null && status != null) {
        resultMap[entityId] = status;
      }
    }

    for (final record in batch) {
      if (record['entity_type'] != 'person') continue;
      final entityId = (record['data'] as Map)['id'] as String?;
      if (entityId == null) continue;

      final resultStatus = resultMap[entityId] ?? 'skipped';
      if (resultStatus == 'inserted' || resultStatus == 'updated' || resultStatus == 'skipped') {
        await _personDS.markAsSynced(entityId);
      } else if (resultStatus == 'failed') {
        await _personDS.markAsFailed(entityId);
      }
    }
  }
}
