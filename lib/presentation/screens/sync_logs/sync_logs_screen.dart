// lib/presentation/screens/sync_logs/sync_logs_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/sync_logger.dart';

class SyncLogsScreen extends ConsumerWidget {
  const SyncLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(syncLoggerProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          'Logs do Sync (${logs.length})',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Copiar tudo',
            icon: const Icon(Icons.copy, color: Colors.white),
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
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
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
                  style: TextStyle(color: Color(0xFF8892B0), fontSize: 13),
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
                        ? const Color(0xFFE53E3E).withValues(alpha: 0.15)
                        : const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(6),
                    border: l.erro
                        ? Border.all(
                            color: const Color(0xFFE53E3E)
                                .withValues(alpha: 0.4))
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.hora,
                        style: const TextStyle(
                          color: Color(0xFF4A5568),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _corEtapa(l.etapa).withValues(alpha: 0.25),
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
                                ? const Color(0xFFFFB4B4)
                                : Colors.white,
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
        return const Color(0xFF38A169);
      case 'outbox':
        return const Color(0xFF4299E1);
      case 'pdvs':
      case 'gabaritos':
      case 'rota':
      case 'edge_function':
      case 'avulsas':
      case 'reconcilia':
      case 'limpeza':
      case 'salvar':
        return const Color(0xFFFFB74D);
      case 'erro':
        return const Color(0xFFE53E3E);
      default:
        return const Color(0xFF8892B0);
    }
  }
}
