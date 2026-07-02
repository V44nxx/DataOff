import 'package:equatable/equatable.dart';

/// Entidad User del dominio
class UserEntity extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String role;  // 'super_admin' | 'admin' | 'asesor' | 'auditor'
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.isActive = true,
    this.lastLogin,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin' || role == 'super_admin';
  bool get isAsesor => role == 'asesor';

  @override
  List<Object?> get props => [id, email, role];
}

/// Resultado de autenticación
class AuthResult extends Equatable {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final UserEntity user;

  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  @override
  List<Object?> get props => [accessToken, user];
}
