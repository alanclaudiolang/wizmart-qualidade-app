// lib/presentation/widgets/bug_report_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/app_colors.dart';
import '../../core/utils/app_router.dart';
import '../../core/utils/bug_report_controller.dart';

/// Ícone discreto de bug report. Fundo transparente, ícone verde.
/// Pra usar dentro de AppBar.actions ou de Rows de header customizado.
class BugReportButton extends ConsumerWidget {
  const BugReportButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(bugReportProvider.notifier);
    final state = ref.watch(bugReportProvider);

    if (state.state == BugRecordingState.exporting) {
      return const SizedBox(
        width: 32,
        height: 32,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      );
    }

    final isRecording = state.state == BugRecordingState.recording;

    return Tooltip(
      message: isRecording ? 'Parar gravação' : 'Reportar bug',
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        iconSize: 20,
        icon: Icon(
          isRecording ? Icons.stop_circle : Icons.bug_report_outlined,
          color: isRecording ? AppColors.danger : AppColors.primary,
        ),
        onPressed: () async {
          final messenger = ScaffoldMessenger.maybeOf(context);
          if (isRecording) {
            final path = await notifier.stopAndExport();
            if (path != null) {
              appRouter.push('/bug-report?gif=${Uri.encodeComponent(path)}');
            } else {
              messenger?.showSnackBar(const SnackBar(
                content: Text('Não foi possível gerar o GIF.'),
                backgroundColor: AppColors.danger,
              ));
            }
          } else {
            notifier.start();
            messenger?.showSnackBar(const SnackBar(
              content: Text(
                  'Gravando... reproduza o bug e toque no ícone vermelho para parar.'),
              duration: Duration(seconds: 3),
              backgroundColor: AppColors.primary,
            ));
          }
        },
      ),
    );
  }
}
