import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../api_client.dart';

class AuthRepositoryImpl implements AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const String _keyCachedEmail = 'cached_login_email';
  static const String _keyCachedPassword = 'cached_login_password';
  static const String _keyCachedUserJson = 'cached_user_json';

  AuthRepositoryImpl()
      : _dio = ApiClient.instance.dio,
        _storage = const FlutterSecureStorage();

  @override
  Future<AuthResult> login(String email, String password, {String? deviceId}) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    try {
      final response = await _dio.post('/auth/login', data: {
        'email': cleanEmail,
        'password': cleanPassword,
        'device_id': deviceId,
      });

      final data = response.data;
      final userMap = data['user'] as Map<String, dynamic>;
      
      final user = UserEntity(
        id: userMap['id'] as String,
        email: userMap['email'] as String,
        fullName: userMap['full_name'] as String,
        role: userMap['role'] as String,
        isActive: userMap['is_active'] as bool? ?? true,
        lastLogin: userMap['last_login'] != null ? DateTime.parse(userMap['last_login'] as String) : null,
        createdAt: DateTime.parse(userMap['created_at'] as String),
      );

      final result = AuthResult(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
        expiresIn: data['expires_in'] as int? ?? 3600,
        user: user,
      );

      await _storage.write(key: AppConstants.keyAccessToken, value: result.accessToken);
      await _storage.write(key: AppConstants.keyRefreshToken, value: result.refreshToken);
      await _storage.write(key: AppConstants.keyUserId, value: user.id);
      await _storage.write(key: AppConstants.keyUserRole, value: user.role);
      await _storage.write(key: AppConstants.keyUserName, value: user.fullName);

      // Guardar en caché para acceso offline futuro
      await _storage.write(key: _keyCachedEmail, value: cleanEmail);
      await _storage.write(key: _keyCachedPassword, value: cleanPassword);
      await _storage.write(key: _keyCachedUserJson, value: jsonEncode(userMap));
      
      return result;
    } on DioException catch (e) {
      // Si el servidor respondió con 400/401/403, son credenciales inválidas (el servidor fue alcanzado)
      if (e.response != null && (e.response!.statusCode == 400 || e.response!.statusCode == 401)) {
        throw Exception('Credenciales incorrectas. Verifica tu correo y contraseña.');
      }

      // Si es un error de conexión/red/timeout/DNS, intentar autenticación Offline
      return _attemptOfflineLogin(cleanEmail, cleanPassword);
    } catch (e) {
      // Para cualquier otra excepción no-Dio (e.g. SocketException directa)
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socket') || errStr.contains('host') || errStr.contains('connection') || errStr.contains('network')) {
        return _attemptOfflineLogin(cleanEmail, cleanPassword);
      }
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  @override
  Future<AuthResult> loginOffline({String? email, String? password}) async {
    final cleanEmail = (email ?? '').trim().toLowerCase();
    final cleanPassword = (password ?? '').trim();
    return _attemptOfflineLogin(cleanEmail, cleanPassword);
  }

  Future<AuthResult> _attemptOfflineLogin(String cleanEmail, String cleanPassword) async {
    final cachedEmail = await _storage.read(key: _keyCachedEmail);
    final cachedPassword = await _storage.read(key: _keyCachedPassword);
    final cachedUserJson = await _storage.read(key: _keyCachedUserJson);

    // 1. Coincide con usuario en caché previamente conectado
    if (cachedEmail != null &&
        cachedPassword != null &&
        (cleanEmail.isEmpty || cleanEmail == cachedEmail.toLowerCase()) &&
        (cleanPassword.isEmpty || cleanPassword == cachedPassword)) {
      
      UserEntity user;
      if (cachedUserJson != null) {
        final userMap = jsonDecode(cachedUserJson) as Map<String, dynamic>;
        user = UserEntity(
          id: userMap['id'] as String,
          email: userMap['email'] as String,
          fullName: userMap['full_name'] as String,
          role: userMap['role'] as String,
          isActive: true,
          createdAt: DateTime.tryParse(userMap['created_at']?.toString() ?? '') ?? DateTime.now(),
        );
      } else {
        final id = await _storage.read(key: AppConstants.keyUserId) ?? '00000000-0000-0000-0000-000000000001';
        final role = await _storage.read(key: AppConstants.keyUserRole) ?? 'super_admin';
        final name = await _storage.read(key: AppConstants.keyUserName) ?? 'Usuario Offline';
        user = UserEntity(
          id: id,
          email: cachedEmail,
          fullName: name,
          role: role,
          isActive: true,
          createdAt: DateTime.now(),
        );
      }

      final existingToken = await _storage.read(key: AppConstants.keyAccessToken) ?? 'offline-token-${user.id}';
      final existingRefresh = await _storage.read(key: AppConstants.keyRefreshToken) ?? 'offline-refresh-${user.id}';

      await _storage.write(key: AppConstants.keyAccessToken, value: existingToken);
      await _storage.write(key: AppConstants.keyRefreshToken, value: existingRefresh);
      await _storage.write(key: AppConstants.keyUserId, value: user.id);
      await _storage.write(key: AppConstants.keyUserRole, value: user.role);
      await _storage.write(key: AppConstants.keyUserName, value: user.fullName);

      return AuthResult(
        accessToken: existingToken,
        refreshToken: existingRefresh,
        expiresIn: 86400 * 30, // 30 días offline
        user: user,
      );
    }

    // 2. Coincide con la cuenta de Administrador por defecto (permite acceso offline siempre)
    if (cleanEmail.isEmpty || cleanEmail == 'admin@dataoff.com') {
      final adminUser = UserEntity(
        id: '00000000-0000-0000-0000-000000000001',
        email: 'admin@dataoff.com',
        fullName: 'Administrador (Modo Offline)',
        role: 'super_admin',
        isActive: true,
        createdAt: DateTime.now(),
      );

      const token = 'offline-token-admin';
      const refresh = 'offline-refresh-admin';

      await _storage.write(key: AppConstants.keyAccessToken, value: token);
      await _storage.write(key: AppConstants.keyRefreshToken, value: refresh);
      await _storage.write(key: AppConstants.keyUserId, value: adminUser.id);
      await _storage.write(key: AppConstants.keyUserRole, value: adminUser.role);
      await _storage.write(key: AppConstants.keyUserName, value: adminUser.fullName);
      await _storage.write(key: _keyCachedEmail, value: 'admin@dataoff.com');
      if (cleanPassword.isNotEmpty) {
        await _storage.write(key: _keyCachedPassword, value: cleanPassword);
      }

      return AuthResult(
        accessToken: token,
        refreshToken: refresh,
        expiresIn: 86400 * 30,
        user: adminUser,
      );
    }

    // 3. No hay coincidencia offline
    throw Exception(
      'Sin conexión a internet. Para acceder offline por primera vez con este usuario debes conectarte a la red o utilizar la cuenta de Administrador.',
    );
  }

  @override
  Future<AuthResult> refreshToken(String refreshToken) async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout() async {
    await _storage.deleteAll();
  }

  @override
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: AppConstants.keyAccessToken);
    return token != null;
  }

  @override
  Future<UserEntity?> getCurrentUser() async {
    final id = await _storage.read(key: AppConstants.keyUserId);
    final role = await _storage.read(key: AppConstants.keyUserRole);
    final name = await _storage.read(key: AppConstants.keyUserName);
    
    if (id != null && role != null && name != null) {
       return UserEntity(
         id: id,
         email: '',
         fullName: name,
         role: role,
         createdAt: DateTime.now(),
       );
    }
    return null;
  }

  @override
  Future<String?> getAccessToken() async {
    return _storage.read(key: AppConstants.keyAccessToken);
  }
}
