import '../entities/person.dart';

/// Interfaz del repositorio de personas
/// El dominio define el contrato; la data layer lo implementa.
/// Permite cambiar SQLite por otro storage sin tocar la lógica.
abstract class PersonRepository {
  /// Obtiene todas las personas locales (incluyendo pendientes de sync)
  Future<List<Person>> getAllPersons();

  /// Busca personas por nombre o documento
  Future<List<Person>> searchPersons(String query);

  /// Obtiene una persona por ID
  Future<Person?> getPersonById(String id);

  /// Guarda una persona localmente (INSERT o UPDATE)
  Future<void> savePerson(Person person);

  /// Soft delete local
  Future<void> deletePerson(String id);

  /// Obtiene todos los registros pendientes de sincronización
  Future<List<Person>> getPendingPersons();

  /// Obtiene personas con sus contactos
  Future<List<Person>> getPersonsWithContacts();

  /// Cuenta registros pendientes
  Future<int> countPending();
}

/// Interfaz del repositorio de contactos
abstract class ContactRepository {
  Future<List<Contact>> getContactsByPersonId(String personId);
  Future<void> saveContact(Contact contact);
  Future<void> deleteContact(String id);
  Future<List<Contact>> getPendingContacts();
}
