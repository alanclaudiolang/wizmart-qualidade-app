// lib/core/utils/device_info_service.dart
//
// Coleta informações do dispositivo e atualiza o campo `device_info`
// (jsonb) da tabela `users` no Supabase. Replica o que o app antigo
// FlutterFlow gravava:
//   { marca, plataforma, versaoApp, fabricante, buildNumber,
//     modeloCelular, versaoSistema }
//
// Falha silenciosa: se offline ou se o update falhar, não atrapalha o
// login do promotor. Próxima vez que entrar online, atualiza.

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class DeviceInfoService {
  DeviceInfoService._();

  static Future<Map<String, dynamic>> collect() async {
    final plugin = DeviceInfoPlugin();
    String marca = '';
    String fabricante = '';
    String modelo = '';
    String versaoSistema = '';
    String plataforma;

    if (Platform.isAndroid) {
      plataforma = 'Android';
      final info = await plugin.androidInfo;
      marca = info.brand;
      fabricante = info.manufacturer;
      modelo = info.model;
      versaoSistema = info.version.release;
    } else if (Platform.isIOS) {
      plataforma = 'iOS';
      final info = await plugin.iosInfo;
      marca = 'apple';
      fabricante = 'Apple';
      modelo = info.utsname.machine;
      versaoSistema = info.systemVersion;
    } else {
      plataforma = Platform.operatingSystem;
    }

    return {
      'marca': marca,
      'plataforma': plataforma,
      'versaoApp': AppConstants.appVersion,
      'fabricante': fabricante,
      'buildNumber': AppConstants.buildNumber,
      'modeloCelular': modelo,
      'versaoSistema': versaoSistema,
    };
  }

  /// Coleta e tenta atualizar `users.device_info` para o usuário dado.
  /// Falha silenciosa: offline / supabase indisponível não atrapalha o
  /// fluxo de login. Timeout curto pra não travar a navegação.
  static Future<void> updateForUser(int userId) async {
    try {
      final info = await collect();
      await Supabase.instance.client
          .from('users')
          .update({'device_info': info})
          .eq('id', userId)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Falha silenciosa por design — esse update não é crítico.
    }
  }
}
