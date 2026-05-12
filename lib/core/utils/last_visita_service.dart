// lib/core/utils/last_visita_service.dart
//
// Persiste o id da última visita aberta. Usado pelo SplashRedirect para
// restaurar o estado quando o Android matar o app por low memory enquanto
// a câmera estava em primeiro plano. Sem isso, o usuário voltaria pra
// home achando que perdeu o trabalho.
//
// O id é setado no initState da VisitaScreen e limpo quando o promotor
// EXPLICITAMENTE sai da visita (botão voltar do AppBar, concluir fotos
// antes ou finalizar visita).

import 'package:shared_preferences/shared_preferences.dart';

class LastVisitaService {
  static const _key = 'last_visita_id';

  static Future<void> set(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, id);
  }

  static Future<int?> get() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
