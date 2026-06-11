---
name: ios-port-pendente
description: "Estado do port iOS — submetido pra App Store + pedido Unlisted, aguardando Apple revisar"
metadata: 
  node_type: memory
  type: project
  originSessionId: <REDACTED_SESSION_ID>
---

Port iOS do Promotor Wizmart finalizado tecnicamente em 2026-05-28. Pipeline
end-to-end funcional. App submetido pra revisão da Apple em 2026-06-01
junto com pedido de distribuição **Unlisted** (não aparece em busca da
App Store, só por link direto). Aguardando Apple processar ambos.

**Conta Apple Developer:** team **JP SMART VENDING OPERADORA DE MAQUINAS
AUTOMATICAS LTDA** (Team ID `<REDACTED_TEAM_ID>`, Issuer ID
`<REDACTED_ISSUER_ID>`, owner <REDACTED_OWNER_EMAIL>).
Bundle ID: **`com.wizmart.promotor`**. App Store Connect app ID `<REDACTED_APP_ID>`.

**CI:** Codemagic (codemagic.yaml na raiz). Workflow `ios-testflight`,
Flutter 3.41.9, Xcode latest, mac_mini_m2. Integração `app_store_connect`
com API key role **Admin** (Key ID `<REDACTED_KEY_ID>`). Variáveis em group
`wizmart-secrets`: `GITHUB_BUG_TOKEN` (auto-report) e `CERT_PRIVATE_KEY`
(RSA persistente — não regenerar por build, senão estoura limite Apple).

**App Store Connect — versão 1.0 configurada via API:**
- Build #12 (iPhone-only, TARGETED_DEVICE_FAMILY=1) anexado
- Descrição, keywords, promotional text pt-BR
- Categoria: Business
- Copyright: © 2026 Wizmart Indústria de Equipamentos
- Privacy URL: PDF hospedado no Supabase storage (reusa do WizMart FlutterFlow)
- Support URL: site corporativo da Wizmart
- Age rating: 4+ (sem conteúdo objetível)
- Pricing: FREE (BRA território base)
- Content rights: DOES_NOT_USE_THIRD_PARTY_CONTENT
- Demo creds pro reviewer: `<REDACTED_DEMO_EMAIL>` / `<REDACTED_DEMO_PASSWORD>`
- 3 Screenshots iPhone 6.7" (login + home + faltas, derivados do Android)
- Privacy Details: 6 categorias (email, GPS, fotos, user_id, crashes,
  diagnostics) — tudo "Funcionalidade do app", linked=Sim, tracking=Não

**Pegadinhas resolvidas (anotadas pra não repetir):**
- `ios_signing.distribution_type` no environment dispara validação prévia
  que procura profile existente. Pra auto-create na 1ª execução usar
  `app-store-connect fetch-signing-files --create --certificate-key=@env:CERT_PRIVATE_KEY`
  (flag certa: `--certificate-key`, NÃO `--certificate-key-path`).
- iOS deployment target precisa ser ≥14.0 (workmanager_apple exige).
- `flutter create --platforms=ios .` rodado com Flutter 3.41.9 (local)
  gera AppDelegate.swift com APIs novas — Codemagic precisa ≥3.41.x.
- Info.plist precisa de `BGTaskSchedulerPermittedIdentifiers` quando
  `UIBackgroundModes: processing` está setado.
- `ITSAppUsesNonExemptEncryption: false` no Info.plist evita popup
  "Faltam dados de conformidade" a cada build.
- AppIcon: defaults do `flutter create` são azuis Flutter. Substituir
  por `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` upscalado.
- Unlisted App Distribution: precisa pedir DURANTE/APÓS submeter pra
  revisão (form em developer.apple.com/contact/request/unlisted-app/
  exige submission ativa). Pedir simultâneo faz Apple aprovar como
  Unlisted direto (sem janela pública na App Store).
- TARGETED_DEVICE_FAMILY=1 (iPhone-only) — universal (1,2) exigia
  screenshots de iPad Pro 12.9" que não temos.

**Status atual:** state=WAITING_FOR_REVIEW (submetido 2026-06-01 16:30 UTC).
Aguardando Apple revisar (24-48h tipico) + processar Unlisted (1-7 dias).

**Webhook Codemagic não dispara automaticamente nos pushes** (motivo
desconhecido, baixa prioridade). Workaround: trigger via API
(`POST /builds` com appId + workflowId + branch). API token em
Codemagic → Settings → Integrations → "Codemagic API" (Show).

Relacionado: [[no-speculation]] (várias falhas iniciais foram corrigidas
chutando; aprendizado: ler CLI --help antes), [[cleanup-fluxo]] (revogar
cert órfão antes de criar novo).
