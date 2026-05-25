// lib/presentation/widgets/permission_help_button.dart
//
// Ícone de ajuda (?) discreto usado nos guards de permissão.
// Quando o promotor tem dúvida ou as configurações não abrem
// automaticamente, ele toca aqui e vê o passo a passo manual.

import 'package:flutter/material.dart';

import '../../core/utils/app_colors.dart';

class PermissionHelpButton extends StatelessWidget {
  final String titulo;
  final List<String> passos;
  const PermissionHelpButton({
    super.key,
    required this.titulo,
    required this.passos,
  });

  void _mostrar(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          titulo,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se a tela de permissão não abrir automaticamente, '
              'siga este caminho no seu celular:',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < passos.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        passos[i],
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _mostrar(context),
      icon: const Icon(Icons.help_outline,
          color: AppColors.textSecondary, size: 20),
      tooltip: 'Ajuda',
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
