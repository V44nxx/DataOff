import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/di/injection.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/sync/sync_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DataOff'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              final syncService = getIt<SyncService>();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sincronizando...')),
              );
              final result = await syncService.syncPendingRecords();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sync completa: ${result.status}')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await getIt<AuthRepository>().logout();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Modo Offline Activo',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Registrar Persona (Offline)'),
              onPressed: () {
                context.push(AppRoutes.personNew);
              },
            ),
          ],
        ),
      ),
    );
  }
}
