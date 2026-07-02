import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../api_client.dart';

class AuthRepositoryImpl implements AuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AuthRepositoryImpl()
      : _dio = ApiClient.instance.dio,
        _storage = const FlutterSecureStorage();

  @override
  Future<AuthResult> login(String email, String password, {String? deviceId}) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
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
      
      return result;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  @override
  Future<AuthResult> refreshToken(String refreshToken) async {
    throw UnimplementedError(); // Handled by interceptor usually, or specific call if needed
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
         email: '', // Not strictly needed for offline checks
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
