// lib/presentation/widgets/gps_guard.dart
//
// Wrapper global que bloqueia toda a UI enquanto o GPS estiver
// desligado ou sem permissão. Promotor depende de geolocalização
// em todas as etapas — desativar mid-task não pode acontecer.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/utils/app_colors.dart';
import '../../core/utils/gps_status_service.dart';

class GpsGuard extends ConsumerWidget {
  final Widget child;
  const GpsGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(gpsStatusProvider);
    return Stack(
      children: [
        child,
        if (status != GpsState.ok && status != GpsState.unknown)
          _GpsBlocker(status: status),
      ],
    );
  }
}

class _GpsBlocker extends ConsumerWidget {
  final GpsState status;
  const _GpsBlocker({required this.status});

  String get _titulo {
    switch (status) {
      case GpsState.serviceDisabled:
        return 'GPS desativado';
      case GpsState.permissionDenied:
      case GpsState.permissionDeniedForever:
        return 'Permissão de localização necessária';
      default:
        return '';
    }
  }

  String get _mensagem {
    switch (status) {
      case GpsState.serviceDisabled:
        return 'O GPS do celular está desligado. '
            'Ative para continuar usando o app.';
      case GpsState.permissionDenied:
        return 'O app precisa acessar sua localização '
            'para registrar as visitas. Toque em "Conceder permissão".';
      case GpsState.permissionDeniedForever:
        return 'A permissão de localização foi negada. '
            'Abra as configurações do app e permita o acesso '
            'à localização para continuar.';
      default:
        return '';
    }
  }

  String get _labelBotao {
    switch (status) {
      case GpsState.serviceDisabled:
        return 'Abrir configurações de GPS';
      case GpsState.permissionDenied:
        return 'Conceder permissão';
      case GpsState.permissionDeniedForever:
        return 'Abrir configurações do app';
      default:
        return '';
    }
  }

  Future<void> _agir(WidgetRef ref) async {
    switch (status) {
      case GpsState.serviceDisabled:
        await Geolocator.openLocationSettings();
        break;
      case GpsState.permissionDenied:
        await Geolocator.requestPermission();
        break;
      case GpsState.permissionDeniedForever:
        await Geolocator.openAppSettings();
        break;
      default:
        break;
    }
    // Força nova checagem ao voltar.
    await ref.read(gpsStatusProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cinza translúcido por cima de TUDO — não só visualmente: o
    // AbsorbPointer + ModalBarrier garantem que nenhum toque chega na
    // tela debaixo. Isso vale durante captura, dentro de dialogs, etc.
    return Positioned.fill(
      child: AbsorbPointer(
        absorbing: true,
        child: ColoredBox(
          color: const Color(0xCCB0B0B0), // cinza ~80% opaco
          child: Material(
            type: MaterialType.transparency,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_off,
                            color: AppColors.danger, size: 56),
                        const SizedBox(height: 16),
                        Text(
                          _titulo,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _mensagem,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _agir(ref),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              _labelBotao,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
