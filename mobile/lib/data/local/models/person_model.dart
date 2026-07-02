import '../../../domain/entities/person.dart';

/// DataOff — Modelo de datos de Persona
/// Convierte entre Map (SQLite) ↔ Person (dominio)
class PersonModel {
  static Person fromMap(Map<String, dynamic> map, {List<Contact> contacts = const []}) {
    return Person(
      id: map['id'] as String,
      userId: map['user_id'] as String?,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      documentType: map['document_type'] as String?,
      documentNumber: map['document_number'] as String?,
      birthDate: map['birth_date'] != null
          ? DateTime.parse(map['birth_date'] as String)
          : null,
      gender: map['gender'] as String?,
      address: map['address'] as String?,
      city: map['city'] as String?,
      department: map['department'] as String?,
      country: (map['country'] as String?) ?? 'Colombia',
      profession: map['profession'] as String?,
      notes: map['notes'] as String?,
      capturedAt: DateTime.parse(map['captured_at'] as String),
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
      syncSource: (map['sync_source'] as String?) ?? 'mobile',
      syncStatus: (map['sync_status'] as String?) ?? 'pending',
      deviceId: map['device_id'] as String?,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      contacts: contacts,
    );
  }

  static Map<String, dynamic> toMap(Person person) {
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
      'profession': person.profession,
      'notes': person.notes,
      'captured_at': person.capturedAt.toIso8601String(),
      'synced_at': person.syncedAt?.toIso8601String(),
      'sync_source': person.syncSource,
      'sync_status': person.syncStatus,
      'device_id': person.deviceId,
      'is_deleted': person.isDeleted ? 1 : 0,
      'created_at': person.createdAt.toIso8601String(),
      'updated_at': person.updatedAt.toIso8601String(),
    };
  }
}

/// Modelo de datos de Contacto
class ContactModel {
  static Contact fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'] as String,
      personId: map['person_id'] as String,
      contactType: map['contact_type'] as String,
      contactValue: map['contact_value'] as String,
      isPrimary: (map['is_primary'] as int? ?? 0) == 1,
      label: map['label'] as String?,
      capturedAt: DateTime.parse(map['captured_at'] as String),
      syncedAt: map['synced_at'] != null
          ? DateTime.parse(map['synced_at'] as String)
          : null,
      syncSource: (map['sync_source'] as String?) ?? 'mobile',
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static Map<String, dynamic> toMap(Contact contact) {
    return {
      'id': contact.id,
      'person_id': contact.personId,
      'contact_type': contact.contactType,
      'contact_value': contact.contactValue,
      'is_primary': contact.isPrimary ? 1 : 0,
      'label': contact.label,
      'captured_at': contact.capturedAt.toIso8601String(),
      'synced_at': contact.syncedAt?.toIso8601String(),
      'sync_source': contact.syncSource,
      'is_deleted': contact.isDeleted ? 1 : 0,
      'created_at': contact.createdAt.toIso8601String(),
      'updated_at': contact.updatedAt.toIso8601String(),
    };
  }
}
