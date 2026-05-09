// lib/core/utils/watermark_util.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class WatermarkUtil {
  static const int _paddingRight = 20;

  static Future<String> applyWatermark({
    required String sourcePath,
    required String pdvNome,
    required String promotorNome,
    required String slot,
    required DateTime capturedAt,
  }) async {
    // path_provider é plugin: precisa rodar no isolate principal.
    // Resolvemos o diretório aqui e passamos para o compute como parâmetro.
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
    final sourcePath   = args['sourcePath']   as String;
    final outPath      = args['outPath']      as String;
    final pdvNome      = args['pdvNome']      as String;
    final promotorNome = args['promotorNome'] as String;
    final slot         = args['slot']         as String;
    final capturedAt   = DateTime.parse(args['capturedAt'] as String);

    final sourceBytes = await File(sourcePath).readAsBytes();
    final original = img.decodeImage(sourceBytes);
    if (original == null) throw Exception('Não foi possível decodificar a imagem');

    const faixaH = 70;
    final novaAltura = original.height + faixaH;
    final novaImagem = img.Image(width: original.width, height: novaAltura);

    img.compositeImage(novaImagem, original, dstX: 0, dstY: 0);

    for (int y = original.height; y < novaAltura; y++) {
      for (int x = 0; x < original.width; x++) {
        novaImagem.setPixelRgba(x, y, 0, 0, 0, 220);
      }
    }

    final dateStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(capturedAt);
    final linha1  = 'PDV: $pdvNome  /  Promotor: $promotorNome';
    final linha2  = 'FOTO $slot  |  $dateStr';
    final font    = img.arial24;

    final l1W = (linha1.length * 14).clamp(0, original.width - _paddingRight);
    img.drawString(novaImagem, linha1,
      font: font,
      x: (original.width - l1W - _paddingRight).clamp(0, original.width - 1),
      y: original.height + 6,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    final l2W = (linha2.length * 14).clamp(0, original.width - _paddingRight);
    img.drawString(novaImagem, linha2,
      font: font,
      x: (original.width - l2W - _paddingRight).clamp(0, original.width - 1),
      y: original.height + 36,
      color: img.ColorRgba8(200, 200, 200, 255),
    );

    await File(outPath).writeAsBytes(img.encodeJpg(novaImagem, quality: 90));
    return outPath;
  }
}
