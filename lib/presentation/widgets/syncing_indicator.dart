// lib/presentation/widgets/syncing_indicator.dart
//
// Setas circulares girando ao lado do indicador de sync no card de cada
// visita, enquanto a visita estiver SENDO sincronizada com o servidor
// (foto subindo OU outbox processando). Visita parada na fila NÃO
// dispara — só quando o engine pegou ela e está mexendo.
//
// Mesmo slot visual da engrenagem (ProcessingIndicator): engrenagem
// reflete watermark+galeria (fase interna, anterior); estas setas
// refletem upload+payload (fase de rede, posterior). Fases sequenciais,
// raramente coincidem.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_colors.dart';
import '../screens/home/home_screen.dart' show visitasSincronizandoProvider;

class SyncingIndicator extends ConsumerWidget {
  final int visitaId;
  const SyncingIndicator({super.key, required this.visitaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ativas = ref.watch(visitasSincronizandoProvider).asData?.value;
    if (ativas == null || !ativas.contains(visitaId)) {
      return const SizedBox.shrink();
    }
    return const _RotatingSync();
  }
}

class _RotatingSync extends StatefulWidget {
  const _RotatingSync();

  @override
  State<_RotatingSync> createState() => _RotatingSyncState();
}

class _RotatingSyncState extends State<_RotatingSync>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Sincronizando...',
      child: RotationTransition(
        turns: _controller,
        child: Icon(
          Icons.sync,
          color: AppColors.primary.withValues(alpha: 0.85),
          size: 14,
        ),
      ),
    );
  }
}
