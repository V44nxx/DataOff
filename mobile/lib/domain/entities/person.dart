import 'package:equatable/equatable.dart';

/// DataOff — Entidad Person del dominio
/// Entidad pura: sin dependencias de Flutter ni de BD.
/// El dominio no sabe nada de SQLite ni de HTTP.
class Person extends Equatable {
  final String id;           // UUID generado en el dispositivo
  final String? userId;
  final String firstName;
  final String lastName;
  final String? documentType;
  final String? documentNumber;
  final DateTime? birthDate;
  final String? gender;
  final String? address;
  final String? city;
  final String? department;
  final String country;
  final String? profession;
  final String? notes;
  final DateTime capturedAt;  // ← INMUTABLE: fecha real de captura
  final DateTime? syncedAt;
  final String syncSource;    // 'mobile' | 'web'
  final String syncStatus;    // 'pending' | 'synced' | 'failed'
  final String? deviceId;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Contact> contacts;

  const Person({
    required this.id,
    this.userId,
    required this.firstName,
    required this.lastName,
    this.documentType,
    this.documentNumber,
    this.birthDate,
    this.gender,
    this.address,
    this.city,
    this.department,
    this.country = 'Colombia',
    this.profession,
    this.notes,
    required this.capturedAt,
    this.syncedAt,
    this.syncSource = 'mobile',
    this.syncStatus = 'pending',
    this.deviceId,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.contacts = const [],
  });

  String get fullName => '$firstName $lastName';

  bool get isSynced => syncStatus == 'synced';
  bool get isPending => syncStatus == 'pending';
  bool get hasFailed => syncStatus == 'failed';

  Person copyWith({
    String? firstName,
    String? lastName,
    String? documentType,
    String? documentNumber,
    DateTime? birthDate,
    String? gender,
    String? address,
    String? city,
    String? department,
    String? country,
    String? profession,
    String? notes,
    DateTime? syncedAt,
    String? syncStatus,
    List<Contact>? contacts,
    DateTime? updatedAt,
  }) {
    return Person(
      id: id,
      userId: userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      address: address ?? this.address,
      city: city ?? this.city,
      department: department ?? this.department,
      country: country ?? this.country,
      profession: profession ?? this.profession,
      notes: notes ?? this.notes,
      capturedAt: capturedAt, // ← NUNCA se modifica
      syncedAt: syncedAt ?? this.syncedAt,
      syncSource: syncSource,
      syncStatus: syncStatus ?? this.syncStatus,
      deviceId: deviceId,
      isDeleted: isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      contacts: contacts ?? this.contacts,
    );
  }

  @override
  List<Object?> get props => [id, firstName, lastName, capturedAt, syncStatus];
}

/// Entidad Contact del dominio
class Contact extends Equatable {
  final String id;
  final String personId;
  final String contactType;  // 'phone' | 'email' | 'whatsapp' | ...
  final String contactValue;
  final bool isPrimary;
  final String? label;
  final DateTime capturedAt;
  final DateTime? syncedAt;
  final String syncSource;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Contact({
    required this.id,
    required this.personId,
    required this.contactType,
    required this.contactValue,
    this.isPrimary = false,
    this.label,
    required this.capturedAt,
    this.syncedAt,
    this.syncSource = 'mobile',
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, personId, contactType, contactValue];
}
