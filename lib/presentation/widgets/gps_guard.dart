// lib/presentation/widgets/gps_guard.dart
//
// Wrapper global que bloqueia toda a UI enquanto o GPS estiver
// desligado ou sem permissão. Promotor depende de geolocalização
// em todas as etapas — desativar mid-task não pode acontecer.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_colors.dart';
import '../../core/utils/gps_status_service.dart';
import 'permission_help_button.dart';

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
    final notifier = ref.read(gpsStatusProvider.notifier);
    switch (status) {
      case GpsState.serviceDisabled:
        await notifier.abrirConfigsGps();
        break;
      case GpsState.permissionDenied:
      case GpsState.permissionDeniedForever:
        // pedir() já trata as duas situações (dialog nativo + fallback
        // pras configurações se ainda não foi concedida).
        await notifier.pedir();
        break;
      default:
        break;
    }
  }

  List<String> get _passosManuais {
    switch (status) {
      case GpsState.serviceDisabled:
        return const [
          'Puxar a barra de notificações',
          'Tocar no ícone de Localização/GPS pra ativar',
          'Voltar pro app e tocar em "Já concedi"',
        ];
      case GpsState.permissionDenied:
      case GpsState.permissionDeniedForever:
        return const [
          'Abrir Configurações do celular',
          'Tocar em Apps (ou Aplicativos)',
          'Encontrar e tocar em "Promotor Wizmart"',
          'Tocar em Permissões',
          'Encontrar "Localização" e ativar',
          'Voltar pro app e tocar em "Já concedi"',
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Stack com duas camadas independentes:
    //   1. ModalBarrier — bloqueia toques pra UI debaixo (cinza
    //      translúcido). Não dismissible — única saída é resolver o GPS.
    //   2. Card no centro — recebe toques normalmente. Estava bugado
    //      antes porque ficava DENTRO do AbsorbPointer, que matava
    //      toda interação inclusive a do próprio botão.
    return Positioned.fill(
      child: Stack(
        children: [
          const ModalBarrier(
            dismissible: false,
            color: Color(0xCCB0B0B0),
          ),
          Material(
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
                        // Linha com ícone central + botão de ajuda no
                        // canto. Sem Positioned negativo (que estava
                        // fazendo o botão cair fora da área tocável).
                        Row(
                          children: [
                            const SizedBox(width: 40),
                            const Spacer(),
                            const Icon(Icons.location_off,
                                color: AppColors.danger, size: 56),
                            const Spacer(),
                            PermissionHelpButton(
                              titulo: _titulo,
                              passos: _passosManuais,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => ref
                                .read(gpsStatusProvider.notifier)
                                .refresh(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10),
                              side: const BorderSide(
                                  color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Já concedi — verificar',
                              style: TextStyle(fontWeight: FontWeight.w500),
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
        ],
      ),
    );
  }
}
