// lib/presentation/screens/realizado/realizado_screen.dart
//
// Histórico de visitas realizadas (status_visita=1 Concluída e 5
// Incompleta) dos últimos 90 dias até hoje. Mostra ✓ verde se aprovada
// pelo supervisor, ✕ vermelho se reprovada, nada se ainda não avaliada
// (visita_aprovada null). Quando houver comentário do supervisor, é
// exibido na segunda linha ao lado da data.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/sync_engine.dart';
import '../../../core/utils/app_colors.dart';
import '../../../core/utils/logout_service.dart';
import '../../../core/utils/session_service.dart';

class RealizadoItem {
  final int? id;
  final String? titulo;
  final String? turno;
  final DateTime dataAgendada;
  final int statusVisita;
  final bool? visitaAprovada;
  final String? comentariosSupervisor;
  RealizadoItem({
    required this.id,
    required this.titulo,
    required this.turno,
    required this.dataAgendada,
    required this.statusVisita,
    required this.visitaAprovada,
    required this.comentariosSupervisor,
  });
}

final realizadoProvider =
    FutureProvider<List<RealizadoItem>>((ref) async {
  final session = await SessionService.getSession();
  if (session == null) return [];

  final hoje = DateTime.now();
  final inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);
  final inicio90d = inicioHoje.subtract(const Duration(days: 90));

  final rows = await Supabase.instance.client
      .from('visitas')
      .select(
          'id,titulo,previsao_turno_realizada,dia_hora_agendado,status_visita,visita_aprovada,comentarios_supervisor')
      .eq('id_promotor_associado', session.userId)
      .or('status_visita.eq.1,status_visita.eq.5')
      .gte('dia_hora_agendado', inicio90d.toUtc().toIso8601String())
      .order('dia_hora_agendado', ascending: false);

  return rows.map<RealizadoItem>((r) {
    final dataStr = r['dia_hora_agendado'] as String?;
    final data = dataStr != null
        ? (DateTime.tryParse(dataStr)?.toLocal() ?? DateTime.now())
        : DateTime.now();
    return RealizadoItem(
      id: r['id'] as int?,
      titulo: r['titulo'] as String?,
      turno: r['previsao_turno_realizada'] as String?,
      dataAgendada: data,
      statusVisita: (r['status_visita'] as int?) ?? 0,
      visitaAprovada: r['visita_aprovada'] as bool?,
      comentariosSupervisor: r['comentarios_supervisor'] as String?,
    );
  }).toList();
});

class RealizadoScreen extends ConsumerWidget {
  const RealizadoScreen({super.key});

  String _labelTurno(String? t) {
    switch (t?.toLowerCase()) {
      case 'manha':
      case 'manhã':
        return 'manhã';
      case 'tarde':
        return 'tarde';
      case 'noite':
        return 'noite';
      default:
        return t ?? '-';
    }
  }

  Future<void> _confirmarLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
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
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Sair',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final db = ref.read(appDatabaseProvider);
    await LogoutService.logoutCompletely(db);
    if (context.mounted) context.go('/auth');
  }

  /// Ícone do veredito do supervisor.
  /// `true`=aprovada (✓ verde), `false`=reprovada (✕ vermelho),
  /// `null`=não avaliada (nada exibido).
  Widget _iconAprovacao(bool? aprovada) {
    if (aprovada == null) return const SizedBox.shrink();
    if (aprovada) {
      return const Icon(Icons.check_circle,
          color: AppColors.success, size: 18);
    }
    return const Icon(Icons.cancel, color: AppColors.danger, size: 18);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realizadoAsync = ref.watch(realizadoProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'Realizado',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
            color: AppColors.card,
            onSelected: (value) async {
              switch (value) {
                case 'home':
                  context.go('/home');
                  break;
                case 'realizado':
                  // Já está aqui — fecha o menu, não navega.
                  break;
                case 'faltas':
                  context.go('/faltas');
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
                value: 'realizado',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: AppColors.success, size: 20),
                    SizedBox(width: 8),
                    Text('Realizado',
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
        onRefresh: () async => ref.invalidate(realizadoProvider),
        child: realizadoAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Icon(Icons.cloud_off, size: 56, color: AppColors.border),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Não foi possível carregar o histórico.\nPuxe pra baixo pra tentar de novo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.event_available,
                      size: 64, color: AppColors.border),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Sem visitas realizadas nos últimos 90 dias',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 15),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final v = items[i];
                final dataFmt =
                    DateFormat('dd/MM/yyyy').format(v.dataAgendada);
                final comentario = v.comentariosSupervisor?.trim();
                final temComentario =
                    comentario != null && comentario.isNotEmpty;
                // Cor da barrinha lateral reflete o status:
                //   1=Concluída → verde, 5=Incompleta → amarelo
                final corBarra = v.statusVisita == 1
                    ? AppColors.success
                    : AppColors.warning;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 4,
                        height: 36,
                        decoration: BoxDecoration(
                          color: corBarra,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              v.titulo?.isNotEmpty == true
                                  ? v.titulo!
                                  : 'PDV ${v.id ?? ''}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              temComentario
                                  ? '$dataFmt · ${_labelTurno(v.turno)} · $comentario'
                                  : '$dataFmt · ${_labelTurno(v.turno)}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _iconAprovacao(v.visitaAprovada),
                      if (v.id != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          '#${v.id}',
                          style: TextStyle(
                            color: AppColors.textMuted
                                .withValues(alpha: 0.55),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
