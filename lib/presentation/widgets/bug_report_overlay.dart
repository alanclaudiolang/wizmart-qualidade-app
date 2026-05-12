// lib/presentation/widgets/bug_report_overlay.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_recorder/screen_recorder.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/bug_report_controller.dart';

/// Envolve o app inteiro com:
/// - ScreenRecorder (captura widgets quando gravando)
/// - FAB flutuante de "Reportar bug" (sempre visível, fora do recorder)
/// - Indicador de gravação no topo
class BugReportOverlay extends ConsumerWidget {
  final Widget child;
  const BugReportOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(bugReportProvider.notifier);
    final state = ref.watch(bugReportProvider);
    final media = MediaQuery.of(context);

    return Stack(
      children: [
        // O app real (gravado quando ativo)
        ScreenRecorder(
          controller: notifier.controller,
          width: media.size.width,
          height: media.size.height,
          background: Colors.black,
          child: child,
        ),

        // Badge "GRAVANDO" centralizado no topo
        if (state.state == BugRecordingState.recording)
          const Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: _RecordingBadge(),
                ),
              ),
            ),
          ),

        // Loading durante exportação (cobre tudo)
        if (state.state == BugRecordingState.exporting)
          const _ExportingOverlay(),
      ],
    );
  }
}

class _RecordingBadge extends StatefulWidget {
  const _RecordingBadge();

  @override
  State<_RecordingBadge> createState() => _RecordingBadgeState();
}

class _RecordingBadgeState extends State<_RecordingBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.danger.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _ctrl,
            child: const Icon(Icons.fiber_manual_record,
                color: AppColors.onDanger, size: 12),
          ),
          const SizedBox(width: 6),
          const Text(
            'GRAVANDO',
            style: TextStyle(
              color: AppColors.onDanger,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportingOverlay extends StatelessWidget {
  const _ExportingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Gerando GIF...',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
