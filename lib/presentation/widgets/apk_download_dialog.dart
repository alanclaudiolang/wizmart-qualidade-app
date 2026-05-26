// lib/presentation/widgets/apk_download_dialog.dart
//
// Dialog modal de download de APK com barra de progresso. Usado tanto
// pelo bloqueio de force-update do HomeScreen quanto pelo da AuthScreen
// (usuário deslogado).

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/utils/apk_updater_service.dart';
import '../../core/utils/app_colors.dart';

class ApkDownloadDialog extends StatefulWidget {
  final String url;
  final CancelToken cancelToken;
  const ApkDownloadDialog({
    super.key,
    required this.url,
    required this.cancelToken,
  });

  @override
  State<ApkDownloadDialog> createState() => _ApkDownloadDialogState();
}

class _ApkDownloadDialogState extends State<ApkDownloadDialog> {
  double _progress = 0.0;
  String? _erro;
  bool _terminado = false;

  @override
  void initState() {
    super.initState();
    _iniciarDownload();
  }

  Future<void> _iniciarDownload() async {
    final result = await ApkUpdaterService.downloadAndInstall(
      url: widget.url,
      cancelToken: widget.cancelToken,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    setState(() {
      _terminado = true;
      if (!result.success && result.error != 'cancelado') {
        _erro = result.error;
      }
    });
    if (result.success && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text(
        _erro != null ? 'Erro ao baixar' : 'Baixando atualização',
        style: const TextStyle(color: AppColors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_erro != null)
            Text(
              _erro!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            )
          else ...[
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: AppColors.border,
              color: AppColors.primary,
              minHeight: 6,
            ),
            const SizedBox(height: 12),
            Text(
              _terminado
                  ? 'Pronto. Toque em "Instalar" no prompt do Android.'
                  : '${(_progress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (!_terminado) {
              widget.cancelToken.cancel();
            }
            Navigator.of(context).pop();
          },
          child: Text(
            _erro != null || _terminado ? 'Fechar' : 'Cancelar',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
