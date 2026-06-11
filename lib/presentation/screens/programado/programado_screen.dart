// lib/presentation/screens/programado/programado_screen.dart
//
// Visitas programadas pros próximos 10 dias (D+1 a D+10). Busca direto
// da Edge Function `gerar_datas_gabaritos_att` com a rota do promotor.
// Sem persistência local — refetch a cada abertura/pull-to-refresh.
// Lista agrupada por data com cabeçalho.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_colors.dart';
import '../../../core/utils/logout_service.dart';
import '../../../core/utils/session_service.dart';

class ProgramadoItem {
  final String titulo;
  final String? turno;
  final DateTime dataAgendada;
  final int? pdvId;
  ProgramadoItem({
    required this.titulo,
    required this.turno,
    required this.dataAgendada,
    required this.pdvId,
  });
}

final programadoProvider =
    FutureProvider<List<ProgramadoItem>>((ref) async {
  final session = await SessionService.getSession();
  if (session == null) return [];

  // 1. Rota + gabaritos do promotor
  final rotaRows = await Supabase.instance.client
      .from('rotas')
      .select('gabaritos_associados')
      .eq('promotor_associado', session.userId);
  if (rotaRows.isEmpty) return [];
  final gabaritos = (rotaRows.first['gabaritos_associados'] as List?)
          ?.whereType<int>()
          .toList() ??
      <int>[];
  if (gabaritos.isEmpty) return [];

  // 2. Range D+1 a D+10
  final hoje = DateTime.now();
  final amanha = DateTime(hoje.year, hoje.month, hoje.day)
      .add(const Duration(days: 1));
  final fim = amanha.add(const Duration(days: 9));
  String fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // 3. Edge Function
  final res = await http
      .post(
        Uri.parse(
            '${AppConstants.supabaseUrl}/functions/v1/gerar_datas_gabaritos_att'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
        },
        body: jsonEncode({
          'gabarito_ids': gabaritos,
          'data_base': fmt(amanha),
          'data_final': fmt(fim),
          'chunk_size': 20,
          'concurrency': 3,
        }),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) return [];
  final list = (jsonDecode(res.body) as List?) ?? const [];

  final items = list.map<ProgramadoItem>((raw) {
    final r = raw as Map<String, dynamic>;
    final dataStr = r['dataAgendada'] as String?;
    DateTime data;
    try {
      data = DateTime.parse(dataStr ?? '');
    } catch (_) {
      data = DateTime.now();
    }
    return ProgramadoItem(
      titulo: (r['titulo'] as String?) ?? '',
      turno: r['turno'] as String?,
      dataAgendada: DateTime(data.year, data.month, data.day),
      pdvId: r['pdv_associado'] as int?,
    );
  }).toList();
  items.sort((a, b) => a.dataAgendada.compareTo(b.dataAgendada));
  return items;
});

class ProgramadoScreen extends ConsumerWidget {
  const ProgramadoScreen({super.key});

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

  String _labelData(DateTime d) {
    // Array fixo evita dependência de initializeDateFormatting('pt_BR').
    const nomes = [
      'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo',
    ];
    // DateTime.weekday: 1=Mon..7=Sun
    final dia = nomes[d.weekday - 1];
    final fmt = DateFormat('dd/MM/yyyy').format(d);
    return '$dia · $fmt';
  }

  Future<void> _confirmarLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Sair do app?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Você vai sair desta sessão. Suas visitas e fotos pendentes '
          'continuam salvas neste dispositivo — quando entrar de novo com '
          'o mesmo e-mail, tudo retoma de onde parou. Continuar?',
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
    await LogoutService.softLogout();
    if (context.mounted) context.go('/auth');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programadoAsync = ref.watch(programadoProvider);

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
          'Programado',
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
                case 'programado':
                  break;
                case 'realizado':
                  context.go('/realizado');
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
                value: 'programado',
                child: Row(
                  children: [
                    Icon(Icons.event_note,
                        color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text('Programado',
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
        onRefresh: () async => ref.invalidate(programadoProvider),
        child: programadoAsync.when(
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
                  'Não foi possível carregar o programado.\nPuxe pra baixo pra tentar de novo.',
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
                      'Sem visitas programadas pros próximos 10 dias',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 15),
                    ),
                  ),
                ],
              );
            }

            // Achata em lista de (header) e (card) preservando ordem.
            final rows = <_Row>[];
            DateTime? lastDate;
            for (final it in items) {
              if (lastDate == null || it.dataAgendada != lastDate) {
                rows.add(_HeaderRow(it.dataAgendada));
                lastDate = it.dataAgendada;
              }
              rows.add(_CardRow(it));
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final r = rows[i];
                if (r is _HeaderRow) {
                  return Padding(
                    padding: EdgeInsets.only(
                        top: i == 0 ? 4 : 16, bottom: 6, left: 4),
                    child: Text(
                      _labelData(r.data),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }
                final v = (r as _CardRow).item;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
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
                                v.titulo.isNotEmpty
                                    ? v.titulo
                                    : 'PDV ${v.pdvId ?? ''}',
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
                                _labelTurno(v.turno),
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

abstract class _Row {}

class _HeaderRow extends _Row {
  final DateTime data;
  _HeaderRow(this.data);
}

class _CardRow extends _Row {
  final ProgramadoItem item;
  _CardRow(this.item);
}
