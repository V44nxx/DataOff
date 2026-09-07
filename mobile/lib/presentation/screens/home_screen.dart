import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/di/injection.dart';
import '../../data/sync/sync_service.dart';
import '../../domain/entities/person.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/person_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Person> _allPersons = [];
  List<Person> _filteredPersons = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadPersons();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPersons() async {
    setState(() => _isLoading = true);
    try {
      final personRepo = getIt<PersonRepository>();
      final persons = await personRepo.getAllPersons();
      if (mounted) {
        setState(() {
          _allPersons = persons;
          _applyFilter(_searchController.text);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar personas: $e')),
        );
      }
    }
  }

  void _onSearchChanged() {
    _applyFilter(_searchController.text);
  }

  void _applyFilter(String query) {
    final term = query.trim().toLowerCase();
    setState(() {
      if (term.isEmpty) {
        _filteredPersons = List.from(_allPersons);
      } else {
        _filteredPersons = _allPersons.where((p) {
          final fullName = p.fullName.toLowerCase();
          final doc = (p.documentNumber ?? '').toLowerCase();
          final city = (p.city ?? '').toLowerCase();
          final profession = (p.profession ?? '').toLowerCase();
          final hasPhoneMatch = p.contacts.any((c) => c.contactValue.toLowerCase().contains(term));
          return fullName.contains(term) ||
              doc.contains(term) ||
              city.contains(term) ||
              profession.contains(term) ||
              hasPhoneMatch;
        }).toList();
      }
    });
  }

  Future<void> _handleSync() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Sincronizando con el servidor cloud...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final syncService = getIt<SyncService>();
      final result = await syncService.syncPendingRecords();
      await _loadPersons();

      if (mounted) {
        String msg = 'Sincronización completada';
        Color bgColor = Colors.green.shade700;

        if (result.status == 'success') {
          if (result.sent == 0) {
            msg = 'Todo está al día. No hay registros pendientes.';
          } else {
            msg = 'Sincronizados: ${result.inserted} nuevos, ${result.updated} actualizados.';
          }
        } else if (result.status == 'partial') {
          msg = 'Sincronización parcial (${result.inserted} ok, ${result.failed} pendientes)';
          bgColor = Colors.orange.shade800;
        } else {
          msg = result.error ?? 'Error en la sincronización. Verifica tu conexión.';
          bgColor = Colors.red.shade700;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: bgColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fallo en sincronización: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  IconData _getContactIcon(String contactType) {
    final type = contactType.toLowerCase();
    if (type.contains('what')) return Icons.chat_bubble_outline;
    if (type.contains('mail') || type.contains('correo')) return Icons.email_outlined;
    return Icons.phone_android;
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _allPersons.where((p) => p.syncStatus == 'pending').length;
    final syncedCount = _allPersons.where((p) => p.syncStatus == 'synced').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.badge_outlined, color: Colors.lightBlueAccent, size: 22),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DataOff Móvil',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                ),
                Text(
                  'Registro Offline & Sincronización',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar ahora',
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.sync_rounded),
            onPressed: _isSyncing ? null : _handleSync,
          ),
          IconButton(
            tooltip: 'Cerrar Sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Cerrar Sesión'),
                  content: const Text('¿Estás seguro de que deseas salir de DataOff?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Salir', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await getIt<AuthRepository>().logout();
                if (context.mounted) {
                  context.go(AppRoutes.login);
                }
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPersons,
        color: const Color(0xFF1E293B),
        child: Column(
          children: [
            // ── PANEL DE ESTADÍSTICAS Y CONTADOR ──────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  // Tarjeta Principal Contador
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PERSONAS REGISTRADAS',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_allPersons.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_android_rounded, size: 14, color: Colors.white70),
                              SizedBox(width: 4),
                              Text(
                                'En este móvil',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Desglose de estado (Sincronizados vs Pendientes)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_done_rounded, color: Color(0xFF4ADE80), size: 18),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sincronizados',
                                    style: TextStyle(color: Colors.white70, fontSize: 10),
                                  ),
                                  Text(
                                    '$syncedCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_upload_rounded, color: Color(0xFFFBBF24), size: 18),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pendientes',
                                    style: TextStyle(color: Colors.white70, fontSize: 10),
                                  ),
                                  Text(
                                    '$pendingCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── BARRA DE BÚSQUEDA ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, cédula o teléfono...',
                  hintStyle: const TextStyle(fontSize: 13, color: Colors.black45),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.blueAccent),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                  ),
                ),
              ),
            ),

            // ── LISTA DE TARJETAS DE PERSONAS ─────────────────
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredPersons.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                          itemCount: _filteredPersons.length,
                          itemBuilder: (context, index) {
                            return _buildPersonCard(_filteredPersons[index]);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'Registrar Persona',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.3),
        ),
        onPressed: () async {
          final saved = await context.push<bool>(AppRoutes.personNew);
          if (saved == true || mounted) {
            await _loadPersons();
          }
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchController.text.trim().isNotEmpty;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearch ? Icons.search_off_rounded : Icons.people_outline_rounded,
                size: 64,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasSearch
                  ? 'No se encontraron resultados'
                  : 'Aún no has registrado personas',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'No hay personas que coincidan con "${_searchController.text.trim()}".'
                  : 'Las personas que registres se guardarán en este teléfono y podrás verlas aquí permanentemente.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!hasSearch)
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Registrar Primera Persona'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  await context.push(AppRoutes.personNew);
                  await _loadPersons();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonCard(Person person) {
    final isSynced = person.syncStatus == 'synced';
    final isPending = person.syncStatus == 'pending';

    // Generar iniciales
    String initials = '';
    if (person.firstName.isNotEmpty) initials += person.firstName[0].toUpperCase();
    if (person.lastName.isNotEmpty) initials += person.lastName[0].toUpperCase();
    if (initials.isEmpty) initials = '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera de la Tarjeta
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar con Iniciales
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nombre y Cédula
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                '${person.documentType ?? 'CC'} ${person.documentNumber ?? 'Sin Doc'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            if (person.profession != null && person.profession!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  person.profession!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Badge de Estado de Sincronización
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSynced
                          ? const Color(0xFFDCFCE7)
                          : isPending
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSynced
                            ? const Color(0xFF86EFAC)
                            : isPending
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFFCA5A5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSynced
                              ? Icons.check_circle_rounded
                              : isPending
                                  ? Icons.access_time_rounded
                                  : Icons.error_outline_rounded,
                          size: 12,
                          color: isSynced
                              ? const Color(0xFF16A34A)
                              : isPending
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFFDC2626),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isSynced
                              ? 'Sincronizado'
                              : isPending
                                  ? 'Pendiente'
                                  : 'Fallo',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSynced
                                ? const Color(0xFF16A34A)
                                : isPending
                                    ? const Color(0xFFB45309)
                                    : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Ubicación (Ciudad / Dirección)
            if ((person.city != null && person.city!.isNotEmpty) ||
                (person.address != null && person.address!.isNotEmpty))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        [person.city, person.address]
                            .where((s) => s != null && s.isNotEmpty)
                            .join(' — '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            // ── LISTA DE CONTACTOS / TELÉFONOS ────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Métodos de Contacto:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${person.contacts.length}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (person.contacts.isEmpty)
                    Text(
                      'Sin números telefónicos o correos guardados',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: person.contacts.asMap().entries.map((entry) {
                        final index = entry.key;
                        final contact = entry.value;
                        final label = contact.label ?? 'Contacto ${index + 1}';

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getContactIcon(contact.contactType),
                                size: 14,
                                color: Colors.blueAccent.shade700,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$label: ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              Text(
                                contact.contactValue,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            // Pie de Tarjeta (Fecha de Captura)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        'Registrado: ${_formatDate(person.capturedAt)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Text(
                    'Origen: ${person.syncSource}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
