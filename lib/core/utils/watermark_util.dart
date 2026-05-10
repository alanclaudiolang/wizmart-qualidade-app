// lib/core/utils/watermark_util.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class WatermarkUtil {
  static const int _padding = 16;

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

    return compute(_processImage, {
      'sourcePath': sourcePath,
      'outPath': outPath,
      'pdvNome': pdvNome,
      'promotorNome': promotorNome,
      'slot': slot,
      'capturedAt': capturedAt.toIso8601String(),
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

    // Faixa dobrada (240px) com 3 linhas em arial48.
    // arial48 ≈ 48px altura. lineHeight 72px = 48 + 24 de gap.
    // Layout: top 24 + linha 72 + linha 72 + linha 48 + bottom 24 = 240
    const faixaH = 240;
    const lineHeight = 72;
    const topPadding = 24;

    final novaAltura = original.height + faixaH;
    final novaImagem = img.Image(width: original.width, height: novaAltura);

    img.compositeImage(novaImagem, original, dstX: 0, dstY: 0);

    img.fillRect(
      novaImagem,
      x1: 0,
      y1: original.height,
      x2: original.width - 1,
      y2: novaAltura - 1,
      color: img.ColorRgb8(0, 0, 0),
    );

    final dateStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(capturedAt);
    final linhas = [
      'PDV: $pdvNome',
      'Promotor: $promotorNome',
      'FOTO $slot  -  $dateStr',
    ];
    final font = img.arial48;
    final corBranca = img.ColorRgb8(255, 255, 255);

    for (var i = 0; i < linhas.length; i++) {
      img.drawString(
        novaImagem,
        linhas[i],
        font: font,
        x: _padding,
        y: original.height + topPadding + (i * lineHeight),
        color: corBranca,
      );
    }

    await File(outPath).writeAsBytes(img.encodeJpg(novaImagem, quality: 90));
    return outPath;
  }
}
