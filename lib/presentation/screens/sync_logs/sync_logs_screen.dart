// lib/presentation/screens/sync_logs/sync_logs_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/app_colors.dart';
import '../../../core/utils/sync_logger.dart';

class SyncLogsScreen extends ConsumerWidget {
  const SyncLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(syncLoggerProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        title: Text(
          'Logs do Sync (${logs.length})',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Copiar tudo',
            icon: const Icon(Icons.copy, color: AppColors.textPrimary),
            onPressed: () async {
              final texto = logs
                  .map((l) =>
                      '${l.hora} [${l.etapa}] ${l.erro ? "ERRO " : ""}${l.mensagem}')
                  .join('\n');
              await Clipboard.setData(ClipboardData(text: texto));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logs copiados para a área de transferência'),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Limpar logs',
            icon: const Icon(Icons.delete_sweep, color: AppColors.textPrimary),
            onPressed: () => ref.read(syncLoggerProvider.notifier).clear(),
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Sem logs ainda.\n\nFaça uma ação no app (iniciar visita, '
                  'tirar foto, concluir) e os logs aparecem aqui em tempo real.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            )
          : ListView.builder(
              reverse: false,
              padding: const EdgeInsets.all(8),
              itemCount: logs.length,
              itemBuilder: (_, i) {
                final l = logs[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: l.erro
                        ? AppColors.dangerBg
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: l.erro
                          ? AppColors.danger.withValues(alpha: 0.4)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.hora,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _corEtapa(l.etapa).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l.etapa,
                          style: TextStyle(
                            color: _corEtapa(l.etapa),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SelectableText(
                          l.mensagem,
                          style: TextStyle(
                            color: l.erro
                                ? AppColors.dangerText
                                : AppColors.textPrimary,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Color _corEtapa(String etapa) {
    switch (etapa) {
      case 'photo':
        return AppColors.primary;
      case 'outbox':
        return AppColors.statusAgendada;
      case 'pdvs':
      case 'gabaritos':
      case 'rota':
      case 'edge_function':
      case 'avulsas':
      case 'reconcilia':
      case 'limpeza':
      case 'salvar':
        return AppColors.warning;
      case 'erro':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }
}
