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

    // Faixa mais alta com fonte maior (arial48 = ~48px de altura).
    // 2 linhas + padding = ~120px.
    const faixaH = 120;
    final novaAltura = original.height + faixaH;
    final novaImagem = img.Image(width: original.width, height: novaAltura);

    // Cola foto original em cima
    img.compositeImage(novaImagem, original, dstX: 0, dstY: 0);

    // Faixa preta sólida (sem alpha — JPG não suporta transparência mesmo)
    img.fillRect(
      novaImagem,
      x1: 0,
      y1: original.height,
      x2: original.width - 1,
      y2: novaAltura - 1,
      color: img.ColorRgb8(0, 0, 0),
    );

    final dateStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(capturedAt);
    final linha1 = 'PDV: $pdvNome';
    final linha2 = 'Promotor: $promotorNome';
    final linha3 = 'FOTO $slot  $dateStr';
    final font = img.arial48;

    img.drawString(
      novaImagem,
      linha1,
      font: font,
      x: _padding,
      y: original.height + 4,
      color: img.ColorRgb8(255, 255, 255),
    );
    img.drawString(
      novaImagem,
      linha2,
      font: font,
      x: _padding,
      y: original.height + 40,
      color: img.ColorRgb8(220, 220, 220),
    );
    img.drawString(
      novaImagem,
      linha3,
      font: font,
      x: _padding,
      y: original.height + 76,
      color: img.ColorRgb8(180, 220, 180),
    );

    await File(outPath).writeAsBytes(img.encodeJpg(novaImagem, quality: 90));
    return outPath;
  }
}
