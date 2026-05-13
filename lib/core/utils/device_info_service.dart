// lib/core/utils/device_info_service.dart
//
// Coleta informações do dispositivo e atualiza o campo `device_info`
// (jsonb) da tabela `users` no Supabase. REPLICA FIELMENTE o que o app
// FlutterFlow antigo gravava (custom action `getDeviceAndAppInfo` +
// `UsersTable().update(data: {device_info: ...}, matchingRows: email)`).
//
// Chaves do JSON (com "platforma" propositalmente, mesmo typo do FF):
//   { versaoApp, buildNumber, platforma, modeloCelular,
//     versaoSistema, fabricante, marca }
//
// Falha silenciosa: se offline ou se o update falhar, não atrapalha o
// login do promotor. Próxima vez que entrar online, atualiza.

import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceInfoService {
  DeviceInfoService._();

  static Future<Map<String, dynamic>> collect() async {
    final pkg = await PackageInfo.fromPlatform();
    final plugin = DeviceInfoPlugin();

    String platforma;
    String modeloCelular = '';
    String versaoSistema = '';
    String fabricante = '';
    String marca = '';

    if (Platform.isAndroid) {
      platforma = 'Android';
      final info = await plugin.androidInfo;
      modeloCelular = info.model;
      versaoSistema = info.version.release;
      fabricante = info.manufacturer;
      marca = info.brand;
    } else if (Platform.isIOS) {
      platforma = 'iOS';
      final info = await plugin.iosInfo;
      modeloCelular = info.utsname.machine;
      versaoSistema = info.systemVersion;
      fabricante = 'Apple';
      marca = 'Apple';
    } else {
      platforma = Platform.operatingSystem;
    }

    return {
      'versaoApp': pkg.version,
      'buildNumber': pkg.buildNumber,
      // Mesmo typo do app FF antigo: 'platforma' (sem 'a' final extra).
      'platforma': platforma,
      'modeloCelular': modeloCelular,
      'versaoSistema': versaoSistema,
      'fabricante': fabricante,
      'marca': marca,
    };
  }

  /// Coleta e tenta atualizar `users.device_info`. Match por email (igual
  /// ao FF antigo). Falha silenciosa: offline / supabase indisponível /
  /// RLS bloqueando não atrapalha o fluxo de login. Timeout curto pra
  /// não travar a navegação.
  static Future<void> updateForEmail(String email) async {
    try {
      final info = await collect();
      await Supabase.instance.client
          .from('users')
          .update({'device_info': info})
          .eq('email', email)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Falha silenciosa por design — esse update não é crítico.
    }
  }
}
