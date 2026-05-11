// lib/presentation/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/sync_engine.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/session_service.dart';
import '../../widgets/bug_report_button.dart';

final sessionProvider = FutureProvider<SessionData?>((ref) async => SessionService.getSession());

final visitasHojeProvider = StreamProvider.family<List<Visita>, int>((ref, promotorId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchVisitasHoje(promotorId);
});

final contadoresProvider = FutureProvider.family<Map<String, int>, int>((ref, promotorId) async {
  final db = ref.watch(appDatabaseProvider);
  return db.getContadoresHoje(promotorId);
});

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
    // Não checa connectivityProvider aqui: ele começa como false e só
    // vira true após o primeiro ping (~1-5s). Tentamos o sync direto;
    // se estivermos offline o supabase client vai jogar a exceção que o
    // try/catch abaixo absorve.
    final syncEngine = ref.read(syncEngineProvider);
    try {
      await syncEngine.pullAll(session.userId);
      await syncEngine.processOutbox();
    } catch (e) {
      debugPrint('Auto-sync falhou: $e');
    }
    // Força UI a buscar dados atualizados após o sync
    if (mounted) {
      ref.invalidate(contadoresProvider(session.userId));
      ref.invalidate(pdvsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider);
    return sessionAsync.when(
      loading: () => const Scaffold(backgroundColor: Color(0xFF1A1A2E), body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('Erro ao carregar sessão'))),
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/auth'));
          return const Scaffold(backgroundColor: Color(0xFF1A1A2E), body: SizedBox());
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
    final visitasAsync = ref.watch(visitasHojeProvider(session.userId));
    final contadoresAsync = ref.watch(contadoresProvider(session.userId));
    final pdvsAsync = ref.watch(pdvsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('WizMart', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Olá, ${session.nome.split(' ').first}', style: const TextStyle(color: Color(0xFF8892B0), fontSize: 13)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BugReportButton(),
                const SizedBox(width: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFF5252),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: isOnline
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFFF5252),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'v${AppConstants.appVersion}.${AppConstants.buildNumber}',
                      style: const TextStyle(
                        color: Color(0xFF8892B0),
                        fontSize: 9,
                      ),
                    ),
                  ],
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
            SliverToBoxAdapter(
              child: contadoresAsync.when(
                loading: () => const _ContadoresLoading(),
                error: (_, __) => const SizedBox(),
                data: (c) => _ContadoresCard(contadores: c),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Visitas de hoje — ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: const TextStyle(color: Color(0xFF8892B0), fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            visitasAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: Padding(padding: EdgeInsets.only(top: 40), child: CircularProgressIndicator(color: Color(0xFF4CAF50)))),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Erro: $e', style: const TextStyle(color: Color(0xFFFF5252))))),
              ),
              data: (visitas) {
                if (visitas.isEmpty) return const SliverToBoxAdapter(child: _EmptyState());
                final pdvs = pdvsAsync.value ?? {};
                final sorted = [...visitas]..sort((a, b) {
                  if (a.diaHoraAgendado == null) return 1;
                  if (b.diaHoraAgendado == null) return -1;
                  return a.diaHoraAgendado!.compareTo(b.diaHoraAgendado!);
                });
                // Bloqueio: se há alguma visita em andamento, só ela pode ser aberta
                final emAndamento = sorted.where((v) => v.statusVisita == 2).toList();
                final temEmAndamento = emAndamento.isNotEmpty;
                final idEmAndamento = temEmAndamento ? emAndamento.first.id : null;
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final v = sorted[index];
                      final pdv = v.idPdvAssociado != null ? pdvs[v.idPdvAssociado!] : null;
                      final bloqueada = temEmAndamento && v.id != idEmAndamento && v.statusVisita == 1;
                      return _VisitaCard(
                        visita: v,
                        pdv: pdv,
                        bloqueada: bloqueada,
                        onTap: () => context.push('/visita/${v.id}'),
                      );
                    },
                    childCount: sorted.length,
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Center(
                  child: Text(
                    'v${AppConstants.appVersion} (build ${AppConstants.buildNumber}) — ${AppConstants.buildTime}',
                    style: const TextStyle(
                      color: Color(0xFF4A5568),
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContadoresCard extends StatelessWidget {
  final Map<String, int> contadores;
  const _ContadoresCard({required this.contadores});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: const Color(0xFF16213E), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CounterItem(label: 'Agendadas', value: contadores['agendadas'] ?? 0, color: const Color(0xFF64B5F6)),
          Container(width: 1, height: 40, color: const Color(0xFF2D3748)),
          _CounterItem(label: 'Realizadas', value: contadores['realizadas'] ?? 0, color: const Color(0xFF4CAF50)),
          Container(width: 1, height: 40, color: const Color(0xFF2D3748)),
          _CounterItem(label: 'Faltas', value: contadores['faltas'] ?? 0, color: const Color(0xFFFF5252)),
        ],
      ),
    );
  }
}

class _CounterItem extends StatelessWidget {
  final String label; final int value; final Color color;
  const _CounterItem({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('$value', style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Color(0xFF8892B0), fontSize: 12)),
    ]);
  }
}

class _ContadoresLoading extends StatelessWidget {
  const _ContadoresLoading();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      height: 80,
      decoration: BoxDecoration(color: const Color(0xFF16213E), borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _VisitaCard extends StatelessWidget {
  final Visita visita;
  final Pdv? pdv;
  final bool bloqueada;
  final VoidCallback onTap;
  const _VisitaCard({
    required this.visita,
    required this.pdv,
    required this.onTap,
    this.bloqueada = false,
  });

  Color get _statusColor {
    switch (visita.statusVisita) {
      case 1: return const Color(0xFF64B5F6);
      case 2: return const Color(0xFFFFB74D);
      case 3: return const Color(0xFF4CAF50);
      case 5: return const Color(0xFFFF5252);
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

  String get _nomePdv {
    // App antigo usa visita.titulo como nome do PDV exibido
    final tituloVisita = visita.titulo;
    if (tituloVisita != null && tituloVisita.isNotEmpty) return tituloVisita;
    if (pdv != null) {
      return pdv!.apiLocalName ?? pdv!.apiLocalCustomerName ?? 'PDV ${pdv!.id}';
    }
    return 'PDV ${visita.idPdvAssociado ?? '?'}';
  }

  String? get _infoLinha {
    try {
      if (visita.statusVisita == 2 && visita.diaHoraAbertura != null) {
        final dt = DateTime.parse(visita.diaHoraAbertura!).toLocal();
        return 'Iniciada às ${DateFormat('HH:mm').format(dt)}';
      }
      if (visita.statusVisita == 3 && visita.diaHoraRealizado != null) {
        final dt = DateTime.parse(visita.diaHoraRealizado!).toLocal();
        return 'Concluída às ${DateFormat('HH:mm').format(dt)}';
      }
    } catch (_) {}
    return null;
  }

  int? get _idReal => visita.id > 0 ? visita.id : null;

  @override
  Widget build(BuildContext context) {
    final emAndamento = visita.statusVisita == 2;
    final finalizada = visita.statusVisita == 3;
    final info = _infoLinha;
    final idReal = _idReal;
    final clicavel = !finalizada && !bloqueada;

    return Opacity(
      opacity: bloqueada ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: clicavel ? onTap : null,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          decoration: BoxDecoration(
            color: bloqueada
                ? const Color(0xFF0F1626)
                : const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: emAndamento
                  ? const Color(0xFFFFB74D).withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 56,
                  decoration: BoxDecoration(
                      color: _statusColor,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_nomePdv,
                          style: TextStyle(
                            color: finalizada
                                ? const Color(0xFF4A5568)
                                : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          )),
                      if (pdv?.endereco != null) ...[
                        const SizedBox(height: 2),
                        Text(pdv!.endereco!,
                            style: const TextStyle(
                                color: Color(0xFF8892B0), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(_statusIcon, size: 14, color: _statusColor),
                        const SizedBox(width: 4),
                        Text(_statusLabel,
                            style: TextStyle(
                                color: _statusColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        if (visita.syncStatus == 'pending')
                          const Icon(Icons.cloud_upload,
                              size: 14, color: Color(0xFFFFB74D))
                        else if (visita.syncStatus == 'synced')
                          const Icon(Icons.cloud_done,
                              size: 14, color: Color(0xFF4CAF50)),
                      ]),
                      if (info != null) ...[
                        const SizedBox(height: 4),
                        Text(info,
                            style: const TextStyle(
                                color: Color(0xFF8892B0), fontSize: 12)),
                      ],
                      if (idReal != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '#$idReal',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (bloqueada)
                  const Icon(Icons.lock_outline,
                      color: Color(0xFF4A5568), size: 20)
                else if (!finalizada)
                  Icon(
                      emAndamento
                          ? Icons.arrow_forward_ios
                          : Icons.play_arrow,
                      color: _statusColor,
                      size: 20),
              ],
            ),
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.event_available, size: 64, color: const Color(0xFF2D3748)),
        const SizedBox(height: 16),
        const Text('Nenhuma visita agendada para hoje', style: TextStyle(color: Color(0xFF4A5568), fontSize: 16)),
        const SizedBox(height: 8),
        const Text('Puxe para baixo para atualizar', style: TextStyle(color: Color(0xFF2D3748), fontSize: 13)),
      ]),
    );
  }
}
