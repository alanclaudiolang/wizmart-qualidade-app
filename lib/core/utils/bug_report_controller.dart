// lib/core/utils/bug_report_controller.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_recorder/screen_recorder.dart';
import 'package:uuid/uuid.dart';

/// Estado da gravação de bug.
enum BugRecordingState { idle, recording, exporting }

class BugReportState {
  final BugRecordingState state;
  final DateTime? startedAt;
  final String? lastGifPath;

  const BugReportState({
    this.state = BugRecordingState.idle,
    this.startedAt,
    this.lastGifPath,
  });

  BugReportState copyWith({
    BugRecordingState? state,
    DateTime? startedAt,
    String? lastGifPath,
  }) {
    return BugReportState(
      state: state ?? this.state,
      startedAt: startedAt ?? this.startedAt,
      lastGifPath: lastGifPath ?? this.lastGifPath,
    );
  }
}

class BugReportNotifier extends StateNotifier<BugReportState> {
  BugReportNotifier()
      : controller = ScreenRecorderController(
          pixelRatio: 0.5,
          skipFramesBetweenCaptures: 5,
        ),
        super(const BugReportState());

  final ScreenRecorderController controller;

  void start() {
    if (state.state != BugRecordingState.idle) return;
    controller.start();
    state = state.copyWith(
      state: BugRecordingState.recording,
      startedAt: DateTime.now(),
    );
  }

  Future<String?> stopAndExport() async {
    if (state.state != BugRecordingState.recording) return null;

    state = state.copyWith(state: BugRecordingState.exporting);
    controller.stop();

    try {
      final List<int>? gifBytes = await controller.exporter.exportGif();
      controller.exporter.clear();

      if (gifBytes == null || gifBytes.isEmpty) {
        state = state.copyWith(state: BugRecordingState.idle);
        return null;
      }

      final dir = await getApplicationDocumentsDirectory();
      final outDir = Directory('${dir.path}/wizmart_bugs');
      await outDir.create(recursive: true);
      final outPath = '${outDir.path}/${const Uuid().v4()}.gif';
      await File(outPath).writeAsBytes(gifBytes);

      state = state.copyWith(
        state: BugRecordingState.idle,
        lastGifPath: outPath,
      );
      return outPath;
    } catch (e, st) {
      debugPrint('Erro ao exportar GIF do bug report: $e\n$st');
      controller.exporter.clear();
      state = state.copyWith(state: BugRecordingState.idle);
      return null;
    }
  }

  void cancel() {
    if (state.state == BugRecordingState.recording) {
      controller.stop();
      controller.exporter.clear();
    }
    state = const BugReportState();
  }
}

final bugReportProvider =
    StateNotifierProvider<BugReportNotifier, BugReportState>(
  (ref) => BugReportNotifier(),
);
