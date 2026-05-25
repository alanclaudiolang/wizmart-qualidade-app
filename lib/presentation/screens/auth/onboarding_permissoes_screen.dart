// lib/presentation/screens/auth/onboarding_permissoes_screen.dart
//
// Tela exibida na PRIMEIRA abertura do app após login. Pede todas as
// permissões críticas (GPS, câmera, galeria) de uma só vez, com o
// mesmo fluxo blindado dos guards (request nativo → fallback pras
// configurações + botão "já concedi" + ícone de ajuda).
//
// Quando todas estão concedidas, grava flag no SharedPreferences e
// segue pra home. Próximas aberturas pulam direto.
//
// Os guards (GpsGuard, PermissionsGuard) continuam ativos como rede
// de segurança caso o promotor revogue alguma permissão depois.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/app_colors.dart';
import '../../../core/utils/gps_status_service.dart';
import '../../../core/utils/permissions_status_service.dart';
import '../../widgets/permission_help_button.dart';

class OnboardingPermissoesScreen extends ConsumerStatefulWidget {
  const OnboardingPermissoesScreen({super.key});

  static const _flagKey = 'onboarding_permissoes_concluido';

  /// Marca como concluído pra não aparecer mais.
  static Future<void> marcarConcluido() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_flagKey, true);
  }

  /// Verifica se já foi concluído alguma vez.
  static Future<bool> jaConcluido() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_flagKey) ?? false;
  }

  @override
  ConsumerState<OnboardingPermissoesScreen> createState() =>
      _OnboardingPermissoesScreenState();
}

class _OnboardingPermissoesScreenState
    extends ConsumerState<OnboardingPermissoesScreen> {
  @override
  void initState() {
    super.initState();
    // Garante que os estados das permissões estejam atualizados
    // assim que a tela monta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gpsStatusProvider.notifier).refresh();
      ref.read(permissionsStatusProvider.notifier).refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gps = ref.watch(gpsStatusProvider);
    final perms = ref.watch(permissionsStatusProvider);
    final gpsOk = gps == GpsState.ok;
    final camOk = perms.camera == PermissionState.granted;
    final midOk = perms.midia == PermissionState.granted;
    final tudoOk = gpsOk && camOk && midOk;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.lock_open,
                  color: AppColors.primary, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Permissões pra usar o app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'O app precisa destas 3 permissões pra funcionar. '
                'Toque em cada uma pra conceder.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _Item(
                      icone: Icons.location_on_outlined,
                      titulo: 'Localização (GPS)',
                      descricao:
                          'Pra registrar onde você está em cada visita.',
                      concedida: gpsOk,
                      passosManuais: gps == GpsState.serviceDisabled
                          ? const [
                              'Puxar a barra de notificações',
                              'Tocar no ícone de Localização/GPS',
                              'Voltar pro app e verificar',
                            ]
                          : const [
                              'Configurações → Apps → Promotor Wizmart',
                              'Permissões → Localização',
                              'Ativar',
                              'Voltar pro app e tocar em "Já concedi"',
                            ],
                      onConceder: () async {
                        final notifier =
                            ref.read(gpsStatusProvider.notifier);
                        if (gps == GpsState.serviceDisabled) {
                          await notifier.abrirConfigsGps();
                        } else {
                          await notifier.pedir();
                        }
                      },
                      onRecheck: () => ref
                          .read(gpsStatusProvider.notifier)
                          .refresh(),
                    ),
                    const SizedBox(height: 12),
                    _Item(
                      icone: Icons.camera_alt_outlined,
                      titulo: 'Câmera',
                      descricao:
                          'Pra tirar as fotos antes e depois das visitas.',
                      concedida: camOk,
                      passosManuais: const [
                        'Configurações → Apps → Promotor Wizmart',
                        'Permissões → Câmera',
                        'Ativar',
                        'Voltar pro app e tocar em "Já concedi"',
                      ],
                      onConceder: () => ref
                          .read(permissionsStatusProvider.notifier)
                          .pedir(PermissionItem.camera),
                      onRecheck: () => ref
                          .read(permissionsStatusProvider.notifier)
                          .refresh(),
                    ),
                    const SizedBox(height: 12),
                    _Item(
                      icone: Icons.photo_library_outlined,
                      titulo: 'Fotos / Galeria',
                      descricao: 'Pra salvar as fotos no seu celular.',
                      concedida: midOk,
                      passosManuais: const [
                        'Configurações → Apps → Promotor Wizmart',
                        'Permissões → Fotos e mídia (ou Arquivos)',
                        'Ativar',
                        'Voltar pro app e tocar em "Já concedi"',
                      ],
                      onConceder: () => ref
                          .read(permissionsStatusProvider.notifier)
                          .pedir(PermissionItem.midia),
                      onRecheck: () => ref
                          .read(permissionsStatusProvider.notifier)
                          .refresh(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: tudoOk
                      ? () async {
                          final router = GoRouter.of(context);
                          await OnboardingPermissoesScreen.marcarConcluido();
                          router.go('/home');
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.35),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    tudoOk
                        ? 'Continuar'
                        : 'Conceda as permissões pendentes',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;
  final bool concedida;
  final List<String> passosManuais;
  final VoidCallback onConceder;
  final VoidCallback onRecheck;

  const _Item({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.concedida,
    required this.passosManuais,
    required this.onConceder,
    required this.onRecheck,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: concedida
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: concedida
              ? AppColors.primary
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                icone,
                color: concedida ? AppColors.primary : AppColors.danger,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (concedida)
                const Icon(Icons.check_circle,
                    color: AppColors.primary, size: 22)
              else
                PermissionHelpButton(
                  titulo: titulo,
                  passos: passosManuais,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            descricao,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12),
          ),
          if (!concedida) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onConceder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Conceder permissão',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRecheck,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Já concedi — verificar',
                  style:
                      TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
