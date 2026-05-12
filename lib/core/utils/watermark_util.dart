// lib/core/utils/watermark_util.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class WatermarkUtil {
  /// Resize moderado antes do watermark: max 2560px no lado maior.
  /// Foto típica de celular é 3000–4000px; reduzir para 2560 corta ~40-60%
  /// do tamanho do arquivo sem perda visual perceptível, e acelera muito o
  /// decode/encode em Dart puro que vem depois.
  static const _maxSide = 2560;
  static const _jpegQuality = 90;

  static Future<String> applyWatermark({
    required String sourcePath,
    required String pdvNome,
    required String promotorNome,
    required String slot,
    required DateTime capturedAt,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final outDir = '${dir.path}/wizmart_fotos';
    await Directory(outDir).create(recursive: true);
    final outPath = '$outDir/${const Uuid().v4()}.jpg';
    final preCompressedPath = '$outDir/${const Uuid().v4()}_pre.jpg';

    // Pre-compress nativo (libjpeg-turbo no Android, ImageIO no iOS) na main
    // isolate — o plugin não funciona dentro de compute(). Resultado: arquivo
    // já redimensionado e recomprimido que o `package:image` vai abrir muito
    // mais rápido para desenhar o watermark.
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

    return compute(_processImage, {
      'sourcePath': inputPath,
      'outPath': outPath,
      'pdvNome': pdvNome,
      'promotorNome': promotorNome,
      'slot': slot,
      'capturedAt': capturedAt.toIso8601String(),
      'isTempInput': usedPreCompressed,
    });
  }

  static Future<String> _processImage(Map<String, dynamic> args) async {
    final sourcePath = args['sourcePath'] as String;
    final outPath = args['outPath'] as String;
    final pdvNome = args['pdvNome'] as String;
    final promotorNome = args['promotorNome'] as String;
    final slot = args['slot'] as String;
    final capturedAt = DateTime.parse(args['capturedAt'] as String);

    final sourceBytes = await File(sourcePath).readAsBytes();
    final original = img.decodeImage(sourceBytes);
    if (original == null) {
      throw Exception('Não foi possível decodificar a imagem');
    }

    // ─── Estratégia: renderizar a faixa em resolução baixa e escalar
    // pra largura da foto. Como `arial48` é fixa em pixels, renderizando
    // numa faixa de 1/4 da largura e depois escalando 4x, o texto vira
    // efetivamente "arial192" — visível mesmo em foto de 4000px.
    //
    // Em foto de 1080×1920: faixaSmall 270×120 → faixaScaled 1080×480
    // Em foto de 4000×3000: faixaSmall 1000×120 → faixaScaled 4000×480
    //
    // Ratio escolhido para que a faixa final fique entre 12-18% da
    // altura da foto, dependendo do aspect ratio.

    const baseSmallH = 120;
    const lineHeight = 36; // arial24 (~24px) com gap
    const topPadding = 12;
    final smallW = (original.width / 4).round().clamp(400, 2000);

    final faixaSmall = img.Image(width: smallW, height: baseSmallH);
    img.fill(faixaSmall, color: img.ColorRgb8(0, 0, 0));

    final dateStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(capturedAt);
    final linhas = [
      'PDV: $pdvNome',
      'Promotor: $promotorNome',
      'FOTO $slot  -  $dateStr',
    ];
    final font = img.arial24;
    final corBranca = img.ColorRgb8(255, 255, 255);

    for (var i = 0; i < linhas.length; i++) {
      img.drawString(
        faixaSmall,
        linhas[i],
        font: font,
        x: 12,
        y: topPadding + (i * lineHeight),
        color: corBranca,
      );
    }

    // Escala 4x — texto fica visualmente 4x maior que arial24 (≈ arial96)
    final faixaScaled = img.copyResize(
      faixaSmall,
      width: original.width,
      interpolation: img.Interpolation.linear,
    );

    // Composita: foto original em cima, faixa escalada embaixo
    final novaAltura = original.height + faixaScaled.height;
    final novaImagem = img.Image(width: original.width, height: novaAltura);
    img.compositeImage(novaImagem, original, dstX: 0, dstY: 0);
    img.compositeImage(novaImagem, faixaScaled,
        dstX: 0, dstY: original.height);

    await File(outPath).writeAsBytes(
      img.encodeJpg(novaImagem, quality: _jpegQuality),
    );

    // Remove arquivo intermediário do pre-compress.
    final isTempInput = (args['isTempInput'] as bool?) ?? false;
    if (isTempInput) {
      try {
        final f = File(sourcePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    return outPath;
  }
}
