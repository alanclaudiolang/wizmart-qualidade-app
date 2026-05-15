// lib/presentation/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/network/sync_engine.dart';
import '../../../core/network/version_check_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/apk_updater_service.dart';
import '../../../core/utils/session_service.dart';
import '../../../core/utils/logout_service.dart';
import '../../../core/utils/app_colors.dart';
import '../../../core/utils/processing_tracker.dart';
import '../../widgets/processing_indicator.dart';

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

// Flag de sessão pra não re-mostrar o dialog de atualização obrigatória
// várias vezes no mesmo open. Reseta naturalmente quando o app é
// fechado/reaberto — alinhado com "primeira vez no dia seguinte".
bool _bloqueioObrigatorioTratado = false;

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _triggerSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // App veio do background: o WorkManager pode ter sincronizado em
    // outro isolate (DB no disco mudou). Invalida os providers da home
    // pra ler dados frescos e dispara um sync no main isolate também.
    if (state == AppLifecycleState.resumed) {
      _triggerSync();
    }
  }

  Future<void> _triggerSync() async {
    final session = await SessionService.getSession();
    if (session == null) return;
    final syncEngine = ref.read(syncEngineProvider);
    try {
      await syncEngine.pullAll(session.userId);
      await syncEngine.processOutbox();
    } catch (e) {
      debugPrint('Auto-sync falhou: $e');
    }
    // Força UI a buscar dados atualizados após o sync.
    if (mounted) {
      ref.invalidate(contadoresProvider(session.userId));
      ref.invalidate(pdvsProvider);
      ref.invalidate(visitasHojeProvider(session.userId));
      // Re-checa GitHub Releases pra detectar build novo (badge "atualizar").
      ref.invalidate(appVersionProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider);
    return sessionAsync.when(
      loading: () => Scaffold(backgroundColor: AppColors.background, body: const Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('Erro ao carregar sessão'))),
      data: (session) {
        if (session == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/auth'));
          return Scaffold(backgroundColor: AppColors.background, body: const SizedBox());
        }
        return _HomeContent(session: session);
      },
    );
  }
}

class _HomeContent extends ConsumerWidget {
  final SessionData session;
  const _HomeContent({required this.session});

  Future<void> _abrirDownloadAPK(
      BuildContext context, WidgetRef ref, AppVersionInfo info) async {
    final url = info.apkDownloadUrl;
    if (url == null) return;

    // Bloqueia o download se houver dados não sincronizados.
    // Instalar uma APK nova por cima pode causar perda de dados que
    // ainda não chegaram ao servidor.
    final db = ref.read(appDatabaseProvider);
    final pendentes = await db.countPendentesParaSync();
    if (pendentes > 0) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text(
            'Não dá pra atualizar agora',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Você tem $pendentes item${pendentes == 1 ? '' : 's'} '
            'pendente${pendentes == 1 ? '' : 's'} de sincronização. '
            'Verifique sua conexão, aguarde o app sincronizar tudo, '
            'e então tente atualizar de novo.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendi',
                  style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    // Dialog modal com barra de progresso. O download roda em
    // background e o usuário pode cancelar a qualquer momento.
    final cancelToken = CancelToken();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ApkDownloadDialog(
        url: url,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<void> _mostrarBloqueioObrigatorio(
      BuildContext context, WidgetRef ref, AppVersionInfo info) async {
    final url = info.apkDownloadUrl;
    if (url == null) {
      _bloqueioObrigatorioTratado = false;
      return;
    }

    // Pré-condição 1: zero pendências de sync E zero visitas em
    // processamento ativo (watermark, upload em curso). Se há,
    // o promotor termina primeiro — bloquear agora arriscaria
    // perder dados em trânsito.
    final db = ref.read(appDatabaseProvider);
    final pendentes = await db.countPendentesParaSync();
    if (pendentes > 0 || ProcessingTracker.total > 0) {
      _bloqueioObrigatorioTratado = false;
      return;
    }

    // Pré-condição 2: APK realmente alcançável (HEAD com timeout 4s).
    // Sem isso, o dialog mostraria mas o download falharia — promotor
    // ficaria preso. Em wifi de hotel/captive portal/DNS quebrado,
    // melhor deixar passar e tentar de novo no próximo gatilho.
    final apkOk = await ApkUpdaterService.apkAcessivel(url);
    if (!apkOk) {
      _bloqueioObrigatorioTratado = false;
      return;
    }

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text(
            'Atualização obrigatória',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Há uma nova versão do app disponível há mais de um dia. '
            'Para continuar usando, é necessário atualizar agora. '
            'Build novo: ${info.latestBuild ?? '?'}.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                if (context.mounted) {
                  await _abrirDownloadAPK(context, ref, info);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
              ),
              child: const Text('Atualizar agora'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Sair do app?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Tudo do seu acesso (login, visitas locais, fotos pendentes, '
          'logs e tarefas) será apagado deste dispositivo. Você precisará '
          'entrar novamente. Continuar?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sair',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // Limpeza centralizada — apaga TODO vestígio do promotor anterior.
    final db = ref.read(appDatabaseProvider);
    await LogoutService.logoutCompletely(db);
    if (context.mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);
    final visitasAsync = ref.watch(visitasHojeProvider(session.userId));
    final pdvsAsync = ref.watch(pdvsProvider);

    // Quando a rede volta (offline → online) enquanto a home está aberta,
    // dispara um sync completo (pullAll + processOutbox) e invalida os
    // providers — sem isso, o promotor precisava pull-to-refresh.
    ref.listen<bool>(connectivityProvider, (prev, next) async {
      if (prev == false && next == true) {
        final engine = ref.read(syncEngineProvider);
        try {
          await engine.pullAll(session.userId);
          await engine.processOutbox();
        } catch (_) {}
        ref.invalidate(contadoresProvider(session.userId));
        ref.invalidate(pdvsProvider);
        ref.invalidate(visitasHojeProvider(session.userId));
        ref.invalidate(appVersionProvider);
      }
    });

    // Bloqueio obrigatório de atualização: quando o release foi
    // publicado em dia anterior ao de hoje, o promotor tem que
    // atualizar antes de continuar. Só dispara se ele está online
    // e SEM pendências (visitas/fotos não sincronizadas).
    ref.listen<AsyncValue<AppVersionInfo>>(appVersionProvider, (_, next) {
      final info = next.asData?.value;
      if (info == null) return;
      if (!info.atualizacaoObrigatoria) return;
      if (!isOnline) return;
      if (_bloqueioObrigatorioTratado) return;
      _bloqueioObrigatorioTratado = true;
      // Atrasa pra dar tempo da home renderizar antes do modal.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) _mostrarBloqueioObrigatorio(context, ref, info);
      });
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WizMart', style: TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Olá, ${session.nome.split(' ').first}', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
        actions: [
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
                          ? AppColors.primary
                          : AppColors.danger,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: isOnline
                          ? AppColors.primary
                          : AppColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                'v${AppConstants.appVersion}.${AppConstants.buildNumber}',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                ),
              ),
              // Badge "Desatualizado" — só aparece se o release v-latest
              // do GitHub tem build maior que o local. Toca pra baixar.
              Consumer(builder: (_, ref, __) {
                final v = ref.watch(appVersionProvider);
                final info = v.asData?.value;
                if (info == null || !info.outdated) {
                  return const SizedBox.shrink();
                }
                return GestureDetector(
                  onTap: () => _abrirDownloadAPK(context, ref, info),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      'atualizar',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.danger,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            color: AppColors.card,
            onSelected: (value) async {
              switch (value) {
                case 'home':
                  // Já está aqui; menu fecha sem navegar.
                  break;
                case 'faltas':
                  if (context.mounted) context.push('/faltas');
                  break;
                case 'logout':
                  await _confirmarLogout(context, ref);
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'home',
                child: Row(
                  children: [
                    Icon(Icons.home_outlined,
                        color: AppColors.textPrimary, size: 20),
                    SizedBox(width: 8),
                    Text('Home',
                        style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'faltas',
                child: Row(
                  children: [
                    Icon(Icons.event_busy,
                        color: AppColors.danger, size: 20),
                    SizedBox(width: 8),
                    Text('Faltas',
                        style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: AppColors.danger, size: 20),
                    SizedBox(width: 8),
                    Text('Sair',
                        style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.card,
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
            // Contadores calculados em memória sobre a lista atual de visitas
            // (sempre atualizado conforme status muda; não depende do DB).
            SliverToBoxAdapter(
              child: visitasAsync.when(
                loading: () => const _ContadoresLoading(),
                error: (_, __) => const SizedBox(),
                data: (visitas) {
                  int agendadas = 0;
                  int andamento = 0;
                  int realizadas = 0;
                  for (final v in visitas) {
                    switch (v.statusVisita) {
                      case 1:
                        agendadas++;
                        break;
                      case 2:
                        andamento++;
                        break;
                      case 3:
                        realizadas++;
                        break;
                    }
                  }
                  final total = agendadas + andamento + realizadas;
                  final pct =
                      total == 0 ? 0 : (realizadas * 100 / total).round();
                  return _ContadoresCard(
                    agendadas: agendadas,
                    realizadas: realizadas,
                    percentual: pct,
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text(
                  'Visitas de hoje — ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            visitasAsync.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: Padding(padding: EdgeInsets.only(top: 40), child: CircularProgressIndicator(color: AppColors.primary))),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Erro: $e', style: TextStyle(color: AppColors.danger)))),
              ),
              data: (visitas) {
                if (visitas.isEmpty) return const SliverToBoxAdapter(child: _EmptyState());
                final pdvs = pdvsAsync.value ?? {};
                // Ordem: em andamento (2) → agendadas (1, por dia_hora_agendado asc)
                // → realizadas (3, por dia_hora_realizado desc) → outros
                int statusPriority(int? s) {
                  if (s == 2) return 0;
                  if (s == 1) return 1;
                  if (s == 3) return 2;
                  return 3;
                }
                int turnoOrder(String? t) {
                  switch (t?.toLowerCase()) {
                    case 'manha':
                    case 'manhã':
                      return 1;
                    case 'tarde':
                      return 2;
                    case 'noite':
                      return 3;
                    default:
                      return 9;
                  }
                }
                final sorted = [...visitas]..sort((a, b) {
                  final pa = statusPriority(a.statusVisita);
                  final pb = statusPriority(b.statusVisita);
                  if (pa != pb) return pa.compareTo(pb);
                  if (a.statusVisita == 3) {
                    // realizadas: mais recente primeiro
                    return (b.diaHoraRealizado ?? '')
                        .compareTo(a.diaHoraRealizado ?? '');
                  }
                  // agendadas: manhã → tarde → noite; empate vai pelo
                  // horário agendado crescente.
                  if (a.statusVisita == 1) {
                    final ta = turnoOrder(a.previsaoTurnoRealizada);
                    final tb = turnoOrder(b.previsaoTurnoRealizada);
                    if (ta != tb) return ta.compareTo(tb);
                  }
                  return (a.diaHoraAgendado ?? '')
                      .compareTo(b.diaHoraAgendado ?? '');
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
                    style: TextStyle(
                      color: AppColors.textMuted,
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
  final int agendadas;
  final int realizadas;
  final int percentual;
  const _ContadoresCard({
    required this.agendadas,
    required this.realizadas,
    required this.percentual,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CounterItem(
              label: 'Agendadas',
              value: '$agendadas',
              color: AppColors.statusAgendada),
          Container(width: 1, height: 40, color: AppColors.border),
          _CounterItem(
              label: 'Realizadas',
              value: '$realizadas',
              color: AppColors.statusRealizada),
          Container(width: 1, height: 40, color: AppColors.border),
          _CounterItem(
              label: '% Realizado',
              value: '$percentual%',
              color: AppColors.statusEmAndamento),
        ],
      ),
    );
  }
}

class _CounterItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CounterItem(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value,
          style: TextStyle(
              color: color, fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
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
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(16)),
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
      case 1: return AppColors.statusAgendada;
      case 2: return AppColors.statusEmAndamento;
      case 3: return AppColors.statusRealizada;
      case 5: return AppColors.statusFalta;
      default: return AppColors.textSecondary;
    }
  }

  String get _statusLabel {
    switch (visita.statusVisita) {
      case 1:
        final t = visita.previsaoTurnoRealizada?.toLowerCase();
        if (t == 'manha' || t == 'manhã') return 'Agendada manhã';
        if (t == 'tarde') return 'Agendada tarde';
        if (t == 'noite') return 'Agendada noite';
        return 'Agendada';
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

  /// Só mostra o id quando a visita está em andamento ou realizada
  /// (não em agendadas/faltas) e quando já foi sincronizada com o servidor.
  int? get _idReal {
    final isStatusComId =
        visita.statusVisita == 2 || visita.statusVisita == 3;
    if (!isStatusComId) return null;
    return visita.serverId;
  }

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
                ? AppColors.inputBg
                : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: emAndamento
                  ? AppColors.statusEmAndamento.withValues(alpha: 0.5)
                  : AppColors.border,
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
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          )),
                      if (pdv?.endereco != null) ...[
                        const SizedBox(height: 2),
                        Text(pdv!.endereco!,
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 12),
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
                          Icon(Icons.cloud_upload,
                              size: 14, color: AppColors.warning)
                        else if (visita.syncStatus == 'synced')
                          Icon(Icons.cloud_done,
                              size: 14, color: AppColors.success),
                        const SizedBox(width: 6),
                        ProcessingIndicator(visitaId: visita.id),
                      ]),
                      if (info != null || idReal != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                info ?? '',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (idReal != null)
                              Text(
                                '#$idReal',
                                style: TextStyle(
                                  color: AppColors.textMuted
                                      .withValues(alpha: 0.55),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (bloqueada)
                  Icon(Icons.lock_outline,
                      color: AppColors.textMuted, size: 20)
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
        Icon(Icons.event_available, size: 64, color: AppColors.border),
        const SizedBox(height: 16),
        Text('Nenhuma visita agendada para hoje', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
        const SizedBox(height: 8),
        Text('Puxe para baixo para atualizar', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      ]),
    );
  }
}


class _ApkDownloadDialog extends StatefulWidget {
  final String url;
  final CancelToken cancelToken;
  const _ApkDownloadDialog({required this.url, required this.cancelToken});

  @override
  State<_ApkDownloadDialog> createState() => _ApkDownloadDialogState();
}

class _ApkDownloadDialogState extends State<_ApkDownloadDialog> {
  double _progress = 0.0;
  String? _erro;
  bool _terminado = false;

  @override
  void initState() {
    super.initState();
    _iniciarDownload();
  }

  Future<void> _iniciarDownload() async {
    final result = await ApkUpdaterService.downloadAndInstall(
      url: widget.url,
      cancelToken: widget.cancelToken,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    setState(() {
      _terminado = true;
      if (!result.success && result.error != 'cancelado') {
        _erro = result.error;
      }
    });
    // Se sucesso (instalador foi disparado), fecha o dialog — o
    // promotor agora interage com o prompt nativo do Android.
    if (result.success && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(
        _erro != null ? 'Erro ao baixar' : 'Baixando atualização',
        style: const TextStyle(color: AppColors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_erro != null)
            Text(
              _erro!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            )
          else ...[
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: AppColors.border,
              color: AppColors.primary,
              minHeight: 6,
            ),
            const SizedBox(height: 12),
            Text(
              _terminado
                  ? 'Pronto. Toque em "Instalar" no prompt do Android.'
                  : '${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (!_terminado) {
              widget.cancelToken.cancel();
            }
            Navigator.of(context).pop();
          },
          child: Text(
            _erro != null || _terminado ? 'Fechar' : 'Cancelar',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
