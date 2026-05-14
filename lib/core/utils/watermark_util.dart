// lib/core/utils/watermark_util.dart
//
// Aplica watermark via Flutter Canvas (Skia HW-accelerated) e encoda
// JPG final via flutter_image_compress (libjpeg-turbo no Android).
//
// IMPORTANTE: NÃO faz mais resize nem pre-compress — a foto já vem
// pronta da câmera (image_picker.maxWidth + imageQuality aplicados na
// captura). Aqui só desenhamos watermark + numeração e recodificamos
// como JPG final.
//
// Funciona em Android 5+ (Skia disponível). Sem fontes externas.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class WatermarkUtil {
  static Future<String> applyWatermark({
    required String sourcePath,
    required String pdvNome,
    required String promotorNome,
    required String slot,
    required DateTime capturedAt,
    int? numero,
    int finalJpegQuality = 88,
    // Apenas pra exibir no rodapé (debug visível em foto problemática).
    int? imgQuality,
    int? maxSide,
    String? tierLabel,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final outDir = '${docs.path}/wizmart_fotos';
    await Directory(outDir).create(recursive: true);
    final uid = const Uuid().v4();
    final outPath = '$outDir/$uid.jpg';

    // ── 1. Decode da foto (Skia nativo).
    final bytes = await File(sourcePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final original = frame.image;
    final w = original.width;
    final h = original.height;

    // ── 2. Dimensões da faixa e fonte proporcionais à foto.
    final faixaH = (h * 0.13).round().clamp(120, 600);
    final fontSize = (w * 0.022).clamp(20.0, 64.0);
    final lineH = fontSize * 1.45;
    final padding = (w * 0.018).clamp(10.0, 48.0);

    // ── 3. Canvas: foto + badge de numeração + faixa + texto + info.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(original, Offset.zero, Paint());

    // Badge de numeração no canto superior direito.
    if (numero != null) {
      final badgeFontSize = (w * 0.040).clamp(28.0, 96.0);
      final badgePadH = (w * 0.022).clamp(14.0, 48.0);
      final badgePadV = (w * 0.012).clamp(8.0, 32.0);
      final badgeMargin = (w * 0.018).clamp(10.0, 48.0);
      final tpBadge = TextPainter(
        text: TextSpan(
          text: '$numero',
          style: TextStyle(
            color: Colors.white,
            fontSize: badgeFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      tpBadge.layout();
      final badgeW = tpBadge.width + badgePadH * 2;
      final badgeH = tpBadge.height + badgePadV * 2;
      final badgeRect = Rect.fromLTWH(
        w - badgeW - badgeMargin,
        badgeMargin,
        badgeW,
        badgeH,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            badgeRect, Radius.circular(badgeH * 0.25)),
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      );
      tpBadge.paint(canvas,
          Offset(badgeRect.left + badgePadH, badgeRect.top + badgePadV));
      tpBadge.dispose();
    }

    // Faixa preta no rodapé.
    canvas.drawRect(
      Rect.fromLTWH(0, h.toDouble(), w.toDouble(), faixaH.toDouble()),
      Paint()..color = Colors.black,
    );

    // 3 linhas principais (PDV / Promotor / FOTO + data).
    final dateStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(capturedAt);
    final linhas = <String>[
      'PDV: $pdvNome',
      'Promotor: $promotorNome',
      'FOTO $slot  -  $dateStr',
    ];
    for (var i = 0; i < linhas.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: linhas[i],
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      );
      tp.layout(maxWidth: w.toDouble() - padding * 2);
      tp.paint(canvas, Offset(padding, h + padding + i * lineH));
      tp.dispose();
    }

    // Linha 4 (canto inferior direito da faixa): info técnica
    // discreta e translúcida — útil pra debug post-mortem de fotos
    // problemáticas. Ex: "imgQ:70 · max1600 · tier:low"
    if (imgQuality != null || maxSide != null) {
      final partes = <String>[];
      if (imgQuality != null) partes.add('imgQ:$imgQuality');
      if (maxSide != null) partes.add('max$maxSide');
      if (tierLabel != null) partes.add(tierLabel);
      final infoText = partes.join(' · ');
      final infoFontSize = (w * 0.016).clamp(14.0, 40.0);
      final tpInfo = TextPainter(
        text: TextSpan(
          text: infoText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: infoFontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      );
      tpInfo.layout(maxWidth: w.toDouble() - padding * 2);
      tpInfo.paint(
        canvas,
        Offset(
          w - tpInfo.width - padding,
          h + faixaH - tpInfo.height - padding * 0.6,
        ),
      );
      tpInfo.dispose();
    }

    // ── 4. Render final.
    final picture = recorder.endRecording();
    final composed = await picture.toImage(w, h + faixaH);
    final pngByteData =
        await composed.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = pngByteData!.buffer.asUint8List();

    original.dispose();
    composed.dispose();
    picture.dispose();

    // ── 5. PNG bytes → JPG bytes nativo (sem I/O de arquivo intermediário).
    final jpgBytes = await FlutterImageCompress.compressWithList(
      pngBytes,
      quality: finalJpegQuality,
      format: CompressFormat.jpeg,
    );
    await File(outPath).writeAsBytes(jpgBytes);
    return outPath;
  }
}
