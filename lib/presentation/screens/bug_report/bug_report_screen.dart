// lib/presentation/screens/bug_report/bug_report_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/github_bug_reporter.dart';
import '../../../core/utils/app_colors.dart';
import '../../../core/utils/session_service.dart';

/// Tela de revisão e envio do bug report.
///
/// Fase 1: salva localmente em arquivo JSON + mantém o GIF.
/// Fase 2/3: upload Supabase + criação de issue no GitHub.
class BugReportScreen extends ConsumerStatefulWidget {
  final String gifPath;
  const BugReportScreen({super.key, required this.gifPath});

  @override
  ConsumerState<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends ConsumerState<BugReportScreen> {
  final _descCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Descreva brevemente o que aconteceu.'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }

    setState(() => _saving = true);

    try {
      final session = await SessionService.getSession();
      final dir = await getApplicationDocumentsDirectory();
      final reportsDir = Directory('${dir.path}/wizmart_bugs/reports');
      await reportsDir.create(recursive: true);

      final id = const Uuid().v4();
      final metadata = {
        'id': id,
        'descricao': _descCtrl.text.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'promotor_id': session?.userId,
        'promotor_nome': session?.nome,
      };

      // Publica no GitHub: commit do GIF + cria issue automaticamente
      final result = await GithubBugReporter.publish(
        reportId: id,
        gifLocalPath: widget.gifPath,
        metadata: metadata,
      );

      // Salva metadata local com status
      final report = {
        ...metadata,
        'gif_path': widget.gifPath,
        'status': result.success ? 'uploaded' : 'pending_upload',
        'issue_url': result.issueUrl,
        'issue_number': result.issueNumber,
        'gif_raw_url': result.gifRawUrl,
        'upload_error': result.error,
      };
      await File('${reportsDir.path}/$id.json')
          .writeAsString(jsonEncode(report));

      if (!mounted) return;
      _showSuccess(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: AppColors.danger,
        ));
        setState(() => _saving = false);
      }
    }
  }

  void _showSuccess(GithubBugReportResult result) {
    final uploaded = result.success;
    final url = result.issueUrl;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        icon: Icon(
          uploaded ? Icons.cloud_done : Icons.cloud_off,
          color: uploaded ? AppColors.primary : AppColors.warning,
          size: 56,
        ),
        title: Text(
          uploaded
              ? 'Issue #${result.issueNumber} criada!'
              : 'Salvo localmente',
          style: const TextStyle(color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              uploaded
                  ? 'A gravação foi enviada ao GitHub e uma issue '
                      'automática foi aberta com o GIF embutido.'
                  : 'Sem internet ou token não configurado — o report '
                      'ficou salvo neste aparelho. '
                      '${result.error != null ? "\n\nDetalhe: ${result.error}" : ""}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (uploaded && url != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                url,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.copy,
                    size: 16, color: AppColors.primary),
                label: const Text('Copiar link',
                    style: TextStyle(color: AppColors.primary)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copiado.')),
                  );
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/home');
            },
            child: const Text('Voltar',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  Future<void> _descartar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Descartar report?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'O GIF gravado será apagado.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final f = File(widget.gifPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}

    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final gifFile = File(widget.gifPath);
    final exists = gifFile.existsSync();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        title: const Text('Reportar problema',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: _saving ? null : _descartar,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview do GIF
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.black,
                constraints: const BoxConstraints(
                  minHeight: 200,
                  maxHeight: 360,
                ),
                child: exists
                    ? Image.file(gifFile, fit: BoxFit.contain)
                    : const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Não foi possível carregar o GIF.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Descrição
            const Text(
              'O que aconteceu?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Conte com suas palavras. Pode ser bem curto.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 4,
              minLines: 3,
              enabled: !_saving,
              decoration: InputDecoration(
                hintText: 'Ex.- "Tirei a foto e ela sumiu da tela."',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 24),

            // Botão enviar
            ElevatedButton.icon(
              onPressed: _saving ? null : _enviar,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send, color: AppColors.onPrimary),
              label: Text(
                _saving ? 'Salvando...' : 'Enviar report',
                style: const TextStyle(
                    color: AppColors.onPrimary, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
