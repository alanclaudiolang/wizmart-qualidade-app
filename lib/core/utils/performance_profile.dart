// lib/core/utils/performance_profile.dart
//
// Detecta a classe do dispositivo (low/mid/high) com base na RAM total
// e expõe os parâmetros de captura e processamento de foto que cada
// tier deve usar.
//
// Detecção acontece UMA vez no startup (RAM total não muda). Cada foto
// só lê o tier — não há custo recorrente.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_info_plus/system_info_plus.dart';

enum PerformanceTier { low, mid, high }

class PerformanceProfile {
  final PerformanceTier tier;
  final int totalRamMb;

  /// Quality do JPG que sai da câmera (image_picker.imageQuality).
  final int imageQuality;

  /// Maior lado da foto que sai da câmera (image_picker.maxWidth/Height).
  /// Mesmo valor pros 2 = "fit dentro de caixa NxN", mantém aspect ratio.
  final int imageMaxSide;

  /// Quality do encode JPG final (após desenhar watermark).
  final int watermarkQuality;

  const PerformanceProfile({
    required this.tier,
    required this.totalRamMb,
    required this.imageQuality,
    required this.imageMaxSide,
    required this.watermarkQuality,
  });

  String get tierLabel {
    switch (tier) {
      case PerformanceTier.low:
        return 'low';
      case PerformanceTier.mid:
        return 'mid';
      case PerformanceTier.high:
        return 'high';
    }
  }

  static PerformanceProfile _byRam(int totalRamMb) {
    if (totalRamMb < 2560) {
      return PerformanceProfile(
        tier: PerformanceTier.low,
        totalRamMb: totalRamMb,
        imageQuality: 70,
        imageMaxSide: 1600,
        watermarkQuality: 88,
      );
    }
    if (totalRamMb < 4096) {
      return PerformanceProfile(
        tier: PerformanceTier.mid,
        totalRamMb: totalRamMb,
        imageQuality: 80,
        imageMaxSide: 2048,
        watermarkQuality: 88,
      );
    }
    return PerformanceProfile(
      tier: PerformanceTier.high,
      totalRamMb: totalRamMb,
      imageQuality: 85,
      imageMaxSide: 2560,
      watermarkQuality: 88,
    );
  }

  /// Default conservador usado enquanto a detecção ainda não terminou.
  /// Equivale a mid — não é nem o pior nem o melhor.
  static final PerformanceProfile padraoCarregando =
      PerformanceProfile._byRam(3072);
}

/// Provider assíncrono. Enquanto a detecção carrega, callers podem usar
/// `.asData?.value ?? PerformanceProfile.padraoCarregando`.
final performanceProfileProvider =
    FutureProvider<PerformanceProfile>((ref) async {
  try {
    final mb = await SystemInfoPlus.physicalMemory;
    if (mb == null || mb <= 0) {
      return PerformanceProfile.padraoCarregando;
    }
    return PerformanceProfile._byRam(mb);
  } catch (_) {
    return PerformanceProfile.padraoCarregando;
  }
});
