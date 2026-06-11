// lib/core/network/sync_pause.dart
//
// Flag persistida em SharedPreferences que pausa o sync em background do
// WorkManager. Setada enquanto o usuário está na tela da visita (tirando
// fotos ou preenchendo checklist) para não consumir CPU/memória/rede do
// dispositivo durante a captura — celulares com pouca RAM podem travar.
//
// Os triggers manuais (em `_iniciarVisita` e `_finalizarVisita`) NÃO
// consultam essa flag: eles disparam o sync imediatamente nas transições
// de status (1→2 e 2→3), que é o único momento em que queremos
// sincronizar com o servidor.

import 'package:shared_preferences/shared_preferences.dart';

class SyncPause {
  static const _key = 'sync_paused';

  static Future<void> pause() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  static Future<void> resume() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
  }

  static Future<bool> isPaused() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }
}
