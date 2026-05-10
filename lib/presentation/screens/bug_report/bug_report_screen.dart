// lib/presentation/screens/bug_report/bug_report_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../core/network/bug_report_uploader.dart';
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
        backgroundColor: Color(0xFFFF5252),
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

      // Upload pro Supabase Storage (bucket "bug-reports")
      final result = await BugReportUploader.upload(
        reportId: id,
        gifLocalPath: widget.gifPath,
        metadata: metadata,
      );

      // Salva metadata local com status do upload
      final report = {
        ...metadata,
        'gif_path': widget.gifPath,
        'status': result.success ? 'uploaded' : 'pending_upload',
        'gif_url': result.gifUrl,
        'json_url': result.jsonUrl,
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
          backgroundColor: const Color(0xFFFF5252),
        ));
        setState(() => _saving = false);
      }
    }
  }

  void _showSuccess(BugReportUploadResult result) {
    final uploaded = result.success;
    final url = result.gifUrl;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        icon: Icon(
          uploaded ? Icons.cloud_done : Icons.cloud_off,
          color: uploaded
              ? const Color(0xFF4CAF50)
              : const Color(0xFFFFB74D),
          size: 56,
        ),
        title: Text(
          uploaded ? 'Report enviado!' : 'Salvo localmente',
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              uploaded
                  ? 'O GIF e a descrição foram enviados ao desenvolvedor. '
                      'Pode continuar usando o app.'
                  : 'Sem internet ou bucket não configurado — o report '
                      'ficou salvo neste aparelho. '
                      '${result.error != null ? "\n\nDetalhe: ${result.error}" : ""}',
              style: const TextStyle(
                  color: Color(0xFF8892B0), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            if (uploaded && url != null) ...[
              const SizedBox(height: 12),
              SelectableText(
                url,
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.copy,
                    size: 16, color: Color(0xFF4CAF50)),
                label: const Text('Copiar link',
                    style: TextStyle(color: Color(0xFF4CAF50))),
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
                style: TextStyle(color: Color(0xFF4CAF50))),
          ),
        ],
      ),
    );
  }

  Future<void> _descartar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('Descartar report?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'O GIF gravado será apagado.',
          style: TextStyle(color: Color(0xFF8892B0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF8892B0))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar',
                style: TextStyle(color: Color(0xFFFF5252))),
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
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        title: const Text('Reportar problema',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
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
                            style: TextStyle(color: Color(0xFF8892B0)),
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
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Conte com suas palavras. Pode ser bem curto.',
              style: TextStyle(color: Color(0xFF8892B0), fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              minLines: 3,
              enabled: !_saving,
              decoration: InputDecoration(
                hintText: 'Ex.- "Tirei a foto e ela sumiu da tela."',
                hintStyle: const TextStyle(color: Color(0xFF4A5568)),
                filled: true,
                fillColor: const Color(0xFF0F0F23),
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
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              label: Text(
                _saving ? 'Salvando...' : 'Enviar report',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
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
