// lib/presentation/widgets/processing_indicator.dart
//
// Ícone de engrenagem girando exibido ao lado do indicador de sync
// no card de cada visita, enquanto a visita estiver sendo processada
// (watermark + galeria + upload + envio pro servidor).

import 'package:flutter/material.dart';

import '../../core/utils/app_colors.dart';
import '../../core/utils/processing_tracker.dart';

class ProcessingIndicator extends StatelessWidget {
  /// Mostra o ícone apenas quando ESTA visita estiver em processamento.
  final int visitaId;
  const ProcessingIndicator({super.key, required this.visitaId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<int>>(
      valueListenable: ProcessingTracker.visitasAtivas,
      builder: (_, ativas, __) {
        if (!ativas.contains(visitaId)) return const SizedBox.shrink();
        return const _RotatingGear();
      },
    );
  }
}

class _RotatingGear extends StatefulWidget {
  const _RotatingGear();

  @override
  State<_RotatingGear> createState() => _RotatingGearState();
}

class _RotatingGearState extends State<_RotatingGear>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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
      message: 'Processando...',
      child: RotationTransition(
        turns: _controller,
        child: Icon(
          Icons.settings,
          color: AppColors.primary.withValues(alpha: 0.7),
          size: 14,
        ),
      ),
    );
  }
}
