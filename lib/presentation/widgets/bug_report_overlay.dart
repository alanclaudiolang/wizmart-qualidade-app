// lib/presentation/widgets/bug_report_overlay.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_recorder/screen_recorder.dart';
import '../../core/utils/app_router.dart';
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

        // Indicador "GRAVANDO" + FAB ficam dentro de SafeArea
        // pra respeitar status bar, notch e edge-to-edge automaticamente.
        Positioned.fill(
          child: SafeArea(
            child: Stack(
              children: [
                if (state.state == BugRecordingState.recording)
                  const Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: _RecordingBadge(),
                    ),
                  ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: _BugFab(state: state.state, notifier: notifier),
                  ),
                ),
              ],
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

class _BugFab extends StatelessWidget {
  final BugRecordingState state;
  final BugReportNotifier notifier;
  const _BugFab({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    if (state == BugRecordingState.exporting) {
      return const SizedBox.shrink();
    }

    final isRecording = state == BugRecordingState.recording;
    final messenger = ScaffoldMessenger.maybeOf(context);

    return Tooltip(
      message: isRecording ? 'Parar gravação' : 'Reportar bug',
      child: Material(
        color: isRecording
            ? const Color(0xFFE53E3E)
            : const Color(0xFF38A169),
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            if (isRecording) {
              final path = await notifier.stopAndExport();
              if (path != null) {
                // Usa appRouter direto — o context deste FAB está acima
                // do Navigator do GoRouter (ele vive no MaterialApp.builder),
                // então context.push() não funcionaria.
                appRouter.push('/bug-report?gif=${Uri.encodeComponent(path)}');
              } else {
                messenger?.showSnackBar(const SnackBar(
                  content: Text('Não foi possível gerar o GIF.'),
                  backgroundColor: Color(0xFFFF5252),
                ));
              }
            } else {
              notifier.start();
              messenger?.showSnackBar(const SnackBar(
                content: Text(
                    'Gravando... reproduza o problema e toque no botão vermelho para parar.'),
                duration: Duration(seconds: 3),
                backgroundColor: Color(0xFF38A169),
              ));
            }
          },
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              isRecording ? Icons.stop : Icons.bug_report_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ),
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
        color: const Color(0xFFE53E3E).withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _ctrl,
            child: const Icon(Icons.fiber_manual_record,
                color: Colors.white, size: 12),
          ),
          const SizedBox(width: 6),
          const Text(
            'GRAVANDO',
            style: TextStyle(
              color: Colors.white,
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
            CircularProgressIndicator(color: Color(0xFF38A169)),
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
