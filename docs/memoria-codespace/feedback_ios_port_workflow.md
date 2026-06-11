---
name: ios-port-workflow
description: "Divisão de trabalho do port iOS — usuário desenvolve no Android, Claude reflete pro iOS"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 89a55c57-a8b0-4de7-b55f-db0e4f1cb76f
---

O usuário desenvolve features/fixes pensando no Android (é a plataforma em
produção). Claude é responsável por refletir essas mudanças no iOS, sem o
usuário ter que pedir a cada vez nem re-explicar o contexto Android (2026-05-28).

**Why:** o app é Flutter — `lib/` (Dart) é compartilhado entre as duas
plataformas, então a MAIOR PARTE de um fix/feature Android já vale pro iOS
automaticamente. "Portar" não é reescrever; é cuidar do que é platform-specific.

**How to apply:** quando o usuário mexer no código Android, revisar o diff
procurando o que precisa de tratamento iOS:
- chamadas a APIs só-Android (ex: `DeviceInfoPlugin().androidInfo` →
  ramificar com `Platform.isIOS`/`iosInfo`);
- código guardado com `Platform.isAndroid` (auto-updater OTA, version check —
  iOS atualiza via TestFlight, ver [[ios-port-pendente]]);
- permissões novas → adicionar a string correspondente em `ios/Runner/Info.plist`
  (Apple rejeita sem descrição); dependências novas no `pubspec.yaml` → conferir
  suporte iOS;
- WorkManager: background no iOS é bem mais limitado que Android.

Fluxo de branches: desenvolver/commitar/push em `dev` sem pedir confirmação
(ver [[feedback-workflow]]); `dev` dispara build de teste, merge pra `main`
publica produção.
