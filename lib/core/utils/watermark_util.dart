// lib/core/utils/watermark_util.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class WatermarkUtil {
  static const double _faixaAltura = 70.0;
  static const double _fontSize = 28.0;
  static const int _paddingRight = 20;
  static const int _paddingBottom = 12;

  /// Gera a foto com faixa de watermark na parte inferior.
  /// Retorna o path do novo arquivo.
  static Future<String> applyWatermark({
    required String sourcePath,
    required int visitaId,
    required String pdvNome,
    required String slot, // 'Antes' ou 'Depois'
    required int numero,
    required DateTime capturedAt,
  }) async {
    return compute(_processImage, {
      'sourcePath': sourcePath,
      'visitaId': visitaId,
      'pdvNome': pdvNome,
      'slot': slot,
      'numero': numero,
      'capturedAt': capturedAt.toIso8601String(),
    });
  }

  static Future<String> _processImage(Map<String, dynamic> args) async {
    final sourcePath = args['sourcePath'] as String;
    final visitaId = args['visitaId'] as int;
    final pdvNome = args['pdvNome'] as String;
    final slot = args['slot'] as String;
    final numero = args['numero'] as int;
    final capturedAt = DateTime.parse(args['capturedAt'] as String);

    // Carrega imagem original
    final sourceFile = File(sourcePath);
    final sourceBytes = await sourceFile.readAsBytes();
    final original = img.decodeImage(sourceBytes);
    if (original == null) throw Exception('Não foi possível decodificar a imagem');

    // Dimensões da faixa
    final faixaH = _faixaAltura.toInt();
    final novaAltura = original.height + faixaH;

    // Cria nova imagem com altura extra
    final novaImagem = img.Image(
      width: original.width,
      height: novaAltura,
    );

    // Copia a foto original na parte superior
    img.compositeImage(novaImagem, original, dstX: 0, dstY: 0);

    // Preenche faixa inferior com preto semitransparente
    for (int y = original.height; y < novaAltura; y++) {
      for (int x = 0; x < original.width; x++) {
        novaImagem.setPixelRgba(x, y, 0, 0, 0, 220);
      }
    }

    // Textos
    final dateStr =
        DateFormat('dd/MM/yyyy HH:mm:ss').format(capturedAt);
    final linha1 = '[$visitaId] $pdvNome';
    final linha2 = 'Foto $slot - Nº$numero  |  $dateStr';

    // Fonte built-in do pacote image
    final font = img.arial24;

    // Linha 1 — nome do PDV (alinhado à direita)
    final l1Width = _estimateTextWidth(linha1, 24);
    final l1X = original.width - l1Width - _paddingRight;
    final l1Y = original.height + 8;
    img.drawString(
      novaImagem,
      linha1,
      font: font,
      x: l1X.clamp(0, original.width - 1),
      y: l1Y,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    // Linha 2 — slot + data (alinhado à direita)
    final l2Width = _estimateTextWidth(linha2, 24);
    final l2X = original.width - l2Width - _paddingRight;
    final l2Y = original.height + 8 + 28 + _paddingBottom;
    img.drawString(
      novaImagem,
      linha2,
      font: font,
      x: l2X.clamp(0, original.width - 1),
      y: l2Y,
      color: img.ColorRgba8(200, 200, 200, 255),
    );

    // Salva o arquivo watermarkado
    final dir = await getApplicationDocumentsDirectory();
    const uuid = Uuid();
    final outPath =
        '${dir.path}/wizmart_fotos/${uuid.v4()}.jpg';
    await Directory('${dir.path}/wizmart_fotos').create(recursive: true);

    final outFile = File(outPath);
    await outFile.writeAsBytes(img.encodeJpg(novaImagem, quality: 90));

    return outPath;
  }

  // Estimativa simples de largura do texto (char ~ 14px para arial24)
  static int _estimateTextWidth(String text, int fontSize) {
    return (text.length * (fontSize * 0.6)).toInt();
  }
}
