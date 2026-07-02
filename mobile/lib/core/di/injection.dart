import 'package:get_it/get_it.dart';

import '../../data/local/datasources/person_local_datasource.dart';
import '../../data/remote/repositories/auth_repository_impl.dart';
import '../../data/sync/sync_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/person_repository.dart';
import '../../domain/usecases/person_usecases.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // ── Data Sources ──────────────────────────────────────────
  getIt.registerLazySingleton<PersonLocalDataSource>(() => PersonLocalDataSource());

  // ── Repositories ──────────────────────────────────────────
  getIt.registerLazySingleton<PersonRepository>(
      () => getIt<PersonLocalDataSource>());
  getIt.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl());

  // ── Services ──────────────────────────────────────────────
  getIt.registerLazySingleton<SyncService>(
      () => SyncService(personDataSource: getIt<PersonLocalDataSource>()));

  // ── Use Cases ─────────────────────────────────────────────
  getIt.registerLazySingleton(() => GetPersonsUseCase(getIt<PersonRepository>()));
  getIt.registerLazySingleton(() => CountPendingUseCase(getIt<PersonRepository>()));
  getIt.registerLazySingleton(() => CreatePersonUseCase(
      getIt<PersonRepository>(), getIt<AuthRepository>()));
}
