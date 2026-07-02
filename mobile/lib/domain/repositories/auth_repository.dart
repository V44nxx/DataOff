import '../entities/user.dart';

/// Interfaz del repositorio de autenticación
abstract class AuthRepository {
  /// Login: retorna tokens y datos del usuario
  Future<AuthResult> login(String email, String password, {String? deviceId});

  /// Refresca el access token usando el refresh token
  Future<AuthResult> refreshToken(String refreshToken);

  /// Logout: revoca el refresh token
  Future<void> logout();

  /// Verifica si hay una sesión activa
  Future<bool> isLoggedIn();

  /// Obtiene el usuario actual desde storage seguro
  Future<UserEntity?> getCurrentUser();

  /// Obtiene el access token actual
  Future<String?> getAccessToken();
}
