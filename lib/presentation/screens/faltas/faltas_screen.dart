// lib/presentation/screens/faltas/faltas_screen.dart
//
// Histórico de faltas (status_visita=5 no servidor) dos últimos 90 dias
// até D-1 (ontem). Lista somente leitura — promotor não interage com os
// cards, é só consulta. Busca direto do Supabase pra ter histórico além
// do dia atual (o DB local guarda só o dia).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/sync_engine.dart';
import '../../../core/utils/app_colors.dart';
import '../../../core/utils/logout_service.dart';
import '../../../core/utils/session_service.dart';

class FaltasItem {
  final int? id;
  final String? titulo;
  final String? turno;
  final DateTime dataAgendada;
  FaltasItem({
    required this.id,
    required this.titulo,
    required this.turno,
    required this.dataAgendada,
  });
}

final faltasProvider = FutureProvider<List<FaltasItem>>((ref) async {
  final session = await SessionService.getSession();
  if (session == null) return [];

  final hoje = DateTime.now();
  final inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);
  final inicio90d = inicioHoje.subtract(const Duration(days: 90));

  final rows = await Supabase.instance.client
      .from('visitas')
      .select(
          'id,titulo,previsao_turno_realizada,dia_hora_agendado,status_visita')
      .eq('id_promotor_associado', session.userId)
      .eq('status_visita', 5)
      .gte('dia_hora_agendado', inicio90d.toUtc().toIso8601String())
      .lt('dia_hora_agendado', inicioHoje.toUtc().toIso8601String())
      .order('dia_hora_agendado', ascending: false);

  return rows.map<FaltasItem>((r) {
    final dataStr = r['dia_hora_agendado'] as String?;
    final data = dataStr != null
        ? (DateTime.tryParse(dataStr)?.toLocal() ?? DateTime.now())
        : DateTime.now();
    return FaltasItem(
      id: r['id'] as int?,
      titulo: r['titulo'] as String?,
      turno: r['previsao_turno_realizada'] as String?,
      dataAgendada: data,
    );
  }).toList();
});

class FaltasScreen extends ConsumerWidget {
  const FaltasScreen({super.key});

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
    final db = ref.read(appDatabaseProvider);
    await LogoutService.logoutCompletely(db);
    if (context.mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faltasAsync = ref.watch(faltasProvider);

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
          'Faltas',
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
                case 'faltas':
                  // Já está aqui — fecha o menu, não navega.
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
        onRefresh: () async => ref.invalidate(faltasProvider),
        child: faltasAsync.when(
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
                  'Não foi possível carregar as faltas.\nPuxe pra baixo pra tentar de novo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
            ],
          ),
          data: (faltas) {
            if (faltas.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.event_available,
                      size: 64, color: AppColors.border),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Sem faltas nos últimos 90 dias',
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
              itemCount: faltas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final f = faltas[i];
                final dataFmt = DateFormat('dd/MM/yyyy').format(f.dataAgendada);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
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
                              f.titulo?.isNotEmpty == true
                                  ? f.titulo!
                                  : 'PDV ${f.id ?? ''}',
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
                              '$dataFmt · ${_labelTurno(f.turno)}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (f.id != null)
                        Text(
                          '#${f.id}',
                          style: TextStyle(
                            color:
                                AppColors.textMuted.withValues(alpha: 0.55),
                            fontSize: 10,
                          ),
                        ),
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
