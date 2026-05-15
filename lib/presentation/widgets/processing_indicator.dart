// lib/presentation/widgets/processing_indicator.dart
//
// Ícone de engrenagem girando — visível na AppBar da home enquanto
// houver operação pesada em andamento (ProcessingCounter > 0).
// Indica ao promotor que o app está trabalhando (watermark, sync,
// upload) e o status pode demorar alguns segundos pra atualizar —
// não está travado.

import 'package:flutter/material.dart';

import '../../core/utils/app_colors.dart';
import '../../core/utils/processing_counter.dart';

class ProcessingIndicator extends StatelessWidget {
  const ProcessingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ProcessingCounter.notifier,
      builder: (_, count, __) {
        if (count <= 0) return const SizedBox.shrink();
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Tooltip(
        message: 'Processando...',
        child: RotationTransition(
          turns: _controller,
          child: const Icon(
            Icons.settings,
            color: AppColors.primary,
            size: 20,
          ),
        ),
      ),
    );
  }
}
