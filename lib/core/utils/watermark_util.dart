// lib/core/utils/watermark_util.dart
//
// Watermark via Flutter Canvas (Skia, hardware-accelerated) + encode JPG
// nativo via flutter_image_compress (libjpeg-turbo no Android).
//
// Substitui a versão anterior que usava `package:image` em Dart puro
// para decode/encode (lento em devices fracos). A nova versão:
//   1. Pre-compress nativo: resize máx 2048px + recompress JPG 90.
//   2. Canvas nativo: desenha foto + faixa + texto.
//   3. Encode final via flutter_image_compress (PNG intermediário → JPG).
//
// Funciona em Android 5+ (mínimo do Flutter atual). Skia/Canvas estão
// disponíveis desde Android 4.4 — sem dependência de GPU especial.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class WatermarkUtil {
  /// Lado maior da imagem final. Reduzir esse valor acelera todo o
  /// pipeline (decode/canvas/encode). 2048px ainda fica nítido pra
  /// visualização normal de foto de PDV.
  static const _maxSide = 2048;

  /// Qualidade JPG do encode final.
  static const _jpegQuality = 88;

  static Future<String> applyWatermark({
    required String sourcePath,
    required String pdvNome,
    required String promotorNome,
    required String slot,
    required DateTime capturedAt,
    int? numero,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final outDir = '${docs.path}/wizmart_fotos';
    await Directory(outDir).create(recursive: true);
    final uid = const Uuid().v4();
    final outPath = '$outDir/$uid.jpg';

    // ── 1. Pre-compress nativo: resize + recompress + strip EXIF.
    //     Resultado: arquivo menor que o Canvas precisará decodificar.
    final preCompressedPath = '$outDir/${uid}_pre.jpg';
    final preResult = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      preCompressedPath,
      minWidth: _maxSide,
      minHeight: _maxSide,
      quality: _jpegQuality,
      keepExif: false,
    );
    final inputPath = preResult?.path ?? sourcePath;
    final usedPreCompressed = preResult != null;

    // ── 2. Decode com instantiateImageCodec (Skia nativo).
    final bytes = await File(inputPath).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final original = frame.image;
    final w = original.width;
    final h = original.height;

    // ── 3. Calcula dimensões da faixa e fonte proporcionais à foto.
    final faixaH = (h * 0.13).round().clamp(120, 600);
    final fontSize = (w * 0.022).clamp(20.0, 64.0);
    final lineH = fontSize * 1.45;
    final padding = (w * 0.018).clamp(10.0, 48.0);

    // ── 4. Desenha tudo no Canvas (Skia hardware-accelerated).
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Foto original ocupa o topo.
    canvas.drawImage(original, Offset.zero, Paint());

    // Badge da numeração no canto superior direito (translúcido,
    // discreto). Só desenha se `numero` foi informado.
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
      // Fundo translúcido (preto ~50% alpha) com cantos arredondados.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          badgeRect,
          Radius.circular(badgeH * 0.25),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      );
      tpBadge.paint(
        canvas,
        Offset(
          badgeRect.left + badgePadH,
          badgeRect.top + badgePadV,
        ),
      );
      tpBadge.dispose();
    }

    // Faixa preta no rodapé (logo abaixo da foto).
    canvas.drawRect(
      Rect.fromLTWH(0, h.toDouble(), w.toDouble(), faixaH.toDouble()),
      Paint()..color = Colors.black,
    );

    // Texto via TextPainter (3 linhas).
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
            // Fonte default do sistema é mais leve e funciona em todos
            // os Android. Sem fontes externas pra evitar ttf bundling.
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

    // ── 5. Render final.
    final picture = recorder.endRecording();
    final composed = await picture.toImage(w, h + faixaH);
    final pngByteData =
        await composed.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = pngByteData!.buffer.asUint8List();

    original.dispose();
    composed.dispose();
    picture.dispose();

    // ── 6. PNG → JPG nativo (PNG sai pesado do Canvas; JPG nativo
    //     é rápido e gera um arquivo bem menor pra subir).
    final tmpPngPath = '$outDir/${uid}_tmp.png';
    final tmpPng = File(tmpPngPath);
    await tmpPng.writeAsBytes(pngBytes);
    final compressResult = await FlutterImageCompress.compressAndGetFile(
      tmpPngPath,
      outPath,
      quality: _jpegQuality,
      format: CompressFormat.jpeg,
    );

    // ── 7. Cleanup: remove temporários.
    try {
      await tmpPng.delete();
    } catch (_) {}
    if (usedPreCompressed) {
      try {
        await File(inputPath).delete();
      } catch (_) {}
    }

    return compressResult?.path ?? outPath;
  }
}
