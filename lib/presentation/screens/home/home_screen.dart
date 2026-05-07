// lib/presentation/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/sync_engine.dart';
import '../../../core/utils/session_service.dart';

// Provider da sessão atual
final sessionProvider = FutureProvider<SessionData?>((ref) async {
  return SessionService.getSession();
});

// Provider das visitas de hoje (stream reativo)
final visitasHojeProvider =
    StreamProvider.family<List<Visita>, int>((ref, promotorId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchVisitasHoje(promotorId);
});

// Provider dos contadores
final contadoresProvider =
    FutureProvider.family<Map<String, int>, int>((ref, promotorId) async {
  final db = ref.watch(appDatabaseProvider);
  return db.getContadoresHoje(promotorId);
});

// Provider dos PDVs (para enriquecer a lista)
final pdvsProvider = FutureProvider<Map<int, Pdv>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final lista = await db.getAllPdvs();
  return {for (final p in lista) p.id: p};
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _triggerSync();
  }

  Future<void> _triggerSync() async {
    final session = await SessionService.getSession();
    if (session == null) return;

    final isOnline = ref.read(connectivityProvider);
    if (!isOnline) return;

    final syncEngine = ref.read(syncEngineProvider);
    await syncEngine.pullAll(session.userId);
    await syncEngine.processOutbox();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider);

    return sessionAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Erro ao carregar sessão')),
      ),
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/auth');
          });
          return const Scaffold(
              backgroundColor: Color(0xFF1A1A2E), body: SizedBox());
        }
        return _HomeContent(session: session);
      },
    );
  }
}

class _HomeContent extends ConsumerWidget {
  final SessionData session;

  const _HomeContent({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    final visitasAsync =
        ref.watch(visitasHojeProvider(session.userId));
    final contadoresAsync =
        ref.watch(contadoresProvider(session.userId));
    final pdvsAsync = ref.watch(pdvsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WizMart',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Olá, ${session.nome.split(' ').first}',
              style: const TextStyle(
                color: Color(0xFF8892B0),
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          // Indicador de conectividade
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF5252),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: isOnline
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF5252),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF4CAF50),
        backgroundColor: const Color(0xFF16213E),
        onRefresh: () async {
          if (isOnline) {
            final syncEngine = ref.read(syncEngineProvider);
            await syncEngine.pullAll(session.userId);
            await syncEngine.processOutbox();
            ref.invalidate(contadoresProvider(session.userId));
          }
        },
        child: CustomScrollView(
          slivers: [
            // ── Contadores ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: contadoresAsync.when(
                loading: () => const _ContadoresLoading(),
                error: (_, __) => const SizedBox(),
                data: (c) => _ContadoresCard(contadores: c),
              ),
            ),

            // ── Data de hoje ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Visitas de hoje — ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: const TextStyle(
                    color: Color(0xFF8892B0),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // ── Lista de visitas ────────────────────────────────────
            visitasAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: CircularProgressIndicator(
                        color: Color(0xFF4CAF50)),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Erro ao carregar visitas: $e',
                      style:
                          const TextStyle(color: Color(0xFFFF5252)),
                    ),
                  ),
                ),
              ),
              data: (visitas) {
                if (visitas.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: _EmptyState(),
                  );
                }

                final pdvs = pdvsAsync.value ?? {};

                // Ordena por horário agendado
                final sorted = [...visitas]..sort((a, b) {
                    if (a.diaHoraAgendado == null) return 1;
                    if (b.diaHoraAgendado == null) return -1;
                    return a.diaHoraAgendado!
                        .compareTo(b.diaHoraAgendado!);
                  });

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final visita = sorted[index];
                      final pdv = visita.idPdvAssociado != null
                          ? pdvs[visita.idPdvAssociado!]
                          : null;
                      return _VisitaCard(
                        visita: visita,
                        pdv: pdv,
                        onTap: () => context.push(
                            '/visita/${visita.id}'),
                      );
                    },
                    childCount: sorted.length,
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ── Contadores ───────────────────────────────────────────────────────────────

class _ContadoresCard extends StatelessWidget {
  final Map<String, int> contadores;

  const _ContadoresCard({required this.contadores});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CounterItem(
            label: 'Agendadas',
            value: contadores['agendadas'] ?? 0,
            color: const Color(0xFF64B5F6),
          ),
          _Divider(),
          _CounterItem(
            label: 'Realizadas',
            value: contadores['realizadas'] ?? 0,
            color: const Color(0xFF4CAF50),
          ),
          _Divider(),
          _CounterItem(
            label: 'Faltas',
            value: contadores['faltas'] ?? 0,
            color: const Color(0xFFFF5252),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: const Color(0xFF2D3748),
    );
  }
}

class _CounterItem extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _CounterItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8892B0),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ContadoresLoading extends StatelessWidget {
  const _ContadoresLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

// ── Card de Visita ───────────────────────────────────────────────────────────

class _VisitaCard extends StatelessWidget {
  final Visita visita;
  final Pdv? pdv;
  final VoidCallback onTap;

  const _VisitaCard({
    required this.visita,
    required this.pdv,
    required this.onTap,
  });

  Color get _statusColor {
    switch (visita.statusVisita) {
      case 1: return const Color(0xFF64B5F6); // agendada
      case 2: return const Color(0xFFFFB74D); // em andamento
      case 3: return const Color(0xFF4CAF50); // realizada
      case 5: return const Color(0xFFFF5252); // falta
      default: return const Color(0xFF8892B0);
    }
  }

  String get _statusLabel {
    switch (visita.statusVisita) {
      case 1: return 'Agendada';
      case 2: return 'Em andamento';
      case 3: return 'Realizada';
      case 5: return 'Falta';
      default: return '';
    }
  }

  IconData get _statusIcon {
    switch (visita.statusVisita) {
      case 1: return Icons.schedule;
      case 2: return Icons.play_circle;
      case 3: return Icons.check_circle;
      case 5: return Icons.cancel;
      default: return Icons.circle;
    }
  }

  String get _horarioFormatado {
    if (visita.diaHoraAgendado == null) return '--:--';
    try {
      final dt = DateTime.parse(visita.diaHoraAgendado!).toLocal();
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return '--:--';
    }
  }

  String get _nomePdv {
    if (pdv == null) return 'PDV ${visita.idPdvAssociado ?? '?'}';
    return pdv!.apiLocalName ??
        pdv!.apiLocalCustomerName ??
        'PDV ${pdv!.id}';
  }

  @override
  Widget build(BuildContext context) {
    final podeIniciar = visita.statusVisita == 1;
    final emAndamento = visita.statusVisita == 2;
    final finalizada = visita.statusVisita == 3;

    return GestureDetector(
      onTap: finalizada ? null : onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: emAndamento
                ? const Color(0xFFFFB74D).withOpacity(0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Indicador de status
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: _statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),

              // Conteúdo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ID da visita + nome do PDV
                    Text(
                      '[${visita.id}] $_nomePdv',
                      style: TextStyle(
                        color: finalizada
                            ? const Color(0xFF4A5568)
                            : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Endereço
                    if (pdv?.endereco != null)
                      Text(
                        pdv!.endereco!,
                        style: const TextStyle(
                          color: Color(0xFF8892B0),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 8),

                    // Horário + status
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 14,
                            color: const Color(0xFF8892B0)),
                        const SizedBox(width: 4),
                        Text(
                          _horarioFormatado,
                          style: const TextStyle(
                            color: Color(0xFF8892B0),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(_statusIcon,
                            size: 14, color: _statusColor),
                        const SizedBox(width: 4),
                        Text(
                          _statusLabel,
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        // Indicador de sync pendente
                        if (visita.syncStatus == 'pending') ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.cloud_upload,
                              size: 14,
                              color: Color(0xFFFFB74D)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Seta de ação
              if (!finalizada)
                Icon(
                  emAndamento
                      ? Icons.arrow_forward_ios
                      : Icons.play_arrow,
                  color: _statusColor,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available,
              size: 64, color: const Color(0xFF2D3748)),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma visita agendada para hoje',
            style: TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Puxe para baixo para atualizar',
            style: TextStyle(
              color: Color(0xFF2D3748),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
