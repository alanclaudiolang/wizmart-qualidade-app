// lib/core/utils/current_screen.dart
//
// Mantém o nome da tela atualmente visível. Atualizado por um
// listener do GoRouter (registrado em app_router.dart). Usado pelo
// ErrorReporter pra incluir o contexto no issue do GitHub e
// aplicar cooldown por tela.

class CurrentScreen {
  CurrentScreen._();

  /// Última tela registrada. Default 'unknown' até o primeiro
  /// `router.routeInformationProvider` disparar.
  static String nome = 'unknown';

  /// Deriva um label legível a partir do path do GoRouter:
  ///   /home         → home
  ///   /visita/123   → visita
  ///   /sync-logs    → sync-logs
  ///   /              → splash
  static String paraNome(String location) {
    final clean = location.split('?').first;
    if (clean == '/' || clean == '/splash') return 'splash';
    final parts = clean.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'home';
    // primeira parte do path basta — ignora ids dinâmicos
    return parts.first;
  }

  static void setFromLocation(String location) {
    nome = paraNome(location);
  }
}
