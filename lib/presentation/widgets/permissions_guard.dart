// lib/presentation/widgets/permissions_guard.dart
//
// Bloqueia toda a UI quando alguma permissão crítica (câmera, galeria)
// está negada. Apresenta as pendências numa lista e pede uma de cada
// vez ou abre configurações em caso de "não perguntar mais".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_colors.dart';
import '../../core/utils/permissions_status_service.dart';
import 'permission_help_button.dart';

class PermissionsGuard extends ConsumerWidget {
  final Widget child;
  const PermissionsGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(permissionsStatusProvider);
    final pendencias = status.pendencias;
    // Mostra UMA permissão de cada vez — câmera antes de mídia (galeria)
    // pra não confundir o promotor com vários popups simultâneos.
    final ordem = [PermissionItem.camera, PermissionItem.midia];
    final proxima = ordem.firstWhere(
      pendencias.contains,
      orElse: () => PermissionItem.camera,
    );
    final temPendencia = pendencias.isNotEmpty;
    return Stack(
      children: [
        child,
        if (temPendencia)
          _PermissionsBlocker(
            pendencias: [proxima],
            status: status,
          ),
      ],
    );
  }
}

class _PermissionsBlocker extends ConsumerWidget {
  final List<PermissionItem> pendencias;
  final PermissionsStatus status;
  const _PermissionsBlocker(
      {required this.pendencias, required this.status});

  String _titulo(PermissionItem item) {
    switch (item) {
      case PermissionItem.camera:
        return 'Câmera';
      case PermissionItem.midia:
        return 'Galeria / Fotos';
    }
  }

  String _descricao(PermissionItem item) {
    switch (item) {
      case PermissionItem.camera:
        return 'Necessária para tirar as fotos das visitas.';
      case PermissionItem.midia:
        return 'Necessária para salvar as fotos no seu celular.';
    }
  }

  IconData _icone(PermissionItem item) {
    switch (item) {
      case PermissionItem.camera:
        return Icons.camera_alt_outlined;
      case PermissionItem.midia:
        return Icons.photo_library_outlined;
    }
  }

  PermissionState _estado(PermissionItem item) {
    switch (item) {
      case PermissionItem.camera:
        return status.camera;
      case PermissionItem.midia:
        return status.midia;
    }
  }

  String _labelBotao(PermissionState s) {
    if (s == PermissionState.permanentlyDenied) {
      return 'Abrir Configurações';
    }
    // Apple guideline 5.1.1(iv): não usar verbos que vianciam o usuário
    // a conceder ("Conceder permissão"). Texto neutro tipo "Continuar".
    return 'Continuar';
  }

  List<String> _passosManuais(PermissionItem item) {
    final nome = item == PermissionItem.camera ? 'Câmera' : 'Fotos e mídia';
    return [
      'Abrir Configurações do celular',
      'Tocar em Apps (ou Aplicativos)',
      'Encontrar e tocar em "Promotor Wizmart"',
      'Tocar em Permissões',
      'Encontrar "$nome" e ativar',
      'Voltar pro app e tocar em "Já concedi"',
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  padding: const EdgeInsets.all(24),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.lock_outline,
                            color: AppColors.danger, size: 56),
                        const SizedBox(height: 16),
                        const Text(
                          'Permissões necessárias',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'O app precisa das permissões abaixo para '
                          'funcionar. Conceda cada uma pra continuar.',
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        for (final item in pendencias) ...[
                          _PermissionRow(
                            icone: _icone(item),
                            titulo: _titulo(item),
                            descricao: _descricao(item),
                            estado: _estado(item),
                            labelBotao: _labelBotao(_estado(item)),
                            passosManuais: _passosManuais(item),
                            onTap: () => ref
                                .read(permissionsStatusProvider.notifier)
                                .pedir(item),
                            onRecheck: () => ref
                                .read(permissionsStatusProvider.notifier)
                                .refresh(),
                          ),
                          const SizedBox(height: 12),
                        ],
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

class _PermissionRow extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;
  final PermissionState estado;
  final String labelBotao;
  final List<String> passosManuais;
  final VoidCallback onTap;
  final VoidCallback onRecheck;

  const _PermissionRow({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.estado,
    required this.labelBotao,
    required this.passosManuais,
    required this.onTap,
    required this.onRecheck,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icone, color: AppColors.danger, size: 22),
              const SizedBox(width: 8),
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
              if (estado == PermissionState.permanentlyDenied)
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 16),
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
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: Text(
                labelBotao,
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text(
                'Já concedi — verificar',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
