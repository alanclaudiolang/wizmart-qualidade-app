// lib/presentation/screens/pendente/pendente_screen.dart
//
// Tela "Pendente" (build 270, pedido do Alan em 12/08): histórico de
// TODAS as visitas ainda não 100% sincronizadas — incluindo as de hoje
// que aparecem na home — na ORDEM em que o sync vai enviá-las (a mesma
// do motor, build 262: visita mais recente primeiro; dentro da visita a
// sequência interna é preservada pelo created_at).
//
// Fonte 100% LOCAL (Drift): pendência é um conceito do aparelho, não do
// servidor. Critérios idênticos ao badge da home
// (watchVisitasComPendencia): row da visita 'pending', foto em
// watermark_pending/pending/uploading/error, ou outbox pending/processing.
// Somente leitura — o promotor não interage com os cards.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/network/sync_engine.dart' show appDatabaseProvider;
import '../../../core/utils/app_colors.dart';

class PendenteItem {
  final Visita visita;
  final int fotosPendentes;
  PendenteItem({required this.visita, required this.fotosPendentes});
}

final pendentesProvider = FutureProvider<List<PendenteItem>>((ref) async {
  final db = ref.read(appDatabaseProvider);
  final visitas = await db.getVisitasComPendencia();
  final itens = <PendenteItem>[];
  for (final v in visitas) {
    final fotos = await db.countFotosPendentesDaVisita(v.id);
    itens.add(PendenteItem(visita: v, fotosPendentes: fotos));
  }
  return itens;
});

class PendenteScreen extends ConsumerWidget {
  const PendenteScreen({super.key});

  /// Data mais representativa da visita (mesma base da ordenação do sync).
  DateTime? _dataVisita(Visita v) {
    final s = v.diaHoraRealizado ?? v.diaHoraAgendado;
    if (s == null) return null;
    return DateTime.tryParse(s)?.toLocal();
  }

  String _oQueFalta(PendenteItem it) {
    final partes = <String>[];
    if (it.fotosPendentes > 0) {
      partes.add(it.fotosPendentes == 1
          ? '1 foto para enviar'
          : '${it.fotosPendentes} fotos para enviar');
    }
    if (it.visita.syncStatus == 'pending') {
      partes.add('dados da visita para enviar');
    }
    if (partes.isEmpty) {
      // Sobrou só item de outbox (raro — ex.: consolidação em curso).
      partes.add('envio em processamento');
    }
    return partes.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendentesAsync = ref.watch(pendentesProvider);

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
          'Pendente',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        onRefresh: () async => ref.invalidate(pendentesProvider),
        child: pendentesAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Icon(Icons.error_outline, size: 56, color: AppColors.border),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Não foi possível carregar as pendências.\n'
                  'Puxe pra baixo pra tentar de novo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
            ],
          ),
          data: (itens) {
            if (itens.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.cloud_done_outlined,
                      size: 64, color: AppColors.border),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Nenhuma pendência — tudo sincronizado!',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 15),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              // +1 pro rodapé explicativo da ordem.
              itemCount: itens.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                if (i == itens.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 8),
                    child: Text(
                      'Os itens acima serão enviados nesta ordem, '
                      'automaticamente, quando houver internet.',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  );
                }
                final it = itens[i];
                final v = it.visita;
                final data = _dataVisita(v);
                final dataFmt = data != null
                    ? DateFormat('dd/MM/yyyy').format(data)
                    : '-';
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
                      // Posição na fila de envio (1 = próxima a subir).
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
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
                                  : 'Visita ${v.id}',
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
                              '$dataFmt · ${_oQueFalta(it)}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.cloud_upload_outlined,
                          color: AppColors.warning, size: 18),
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
