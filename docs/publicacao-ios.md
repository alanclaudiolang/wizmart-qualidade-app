# Publicação iOS — status e contexto consolidado

> Consolidado em 11/06/2026 a partir de: memórias recuperadas do Codespace
> (`docs/memoria-codespace/`), histórico de commits do repo e verificações
> feitas em 11/06 (API pública da Apple, codemagic.yaml). Substitui o
> contexto que estava preso no Codespace.

## Status em 11/06/2026

- App **submetido à revisão da App Store em 01/06/2026 16:30 UTC** (versão
  1.0, build #12), **junto com pedido de distribuição Unlisted** (app não
  aparece na busca da App Store; instala só por link direto — adequado a
  app privado de promotores).
- Depois da submissão, a Apple **rejeitou 3 vezes**; as 3 causas foram
  corrigidas no código até 04/06 (ver linha do tempo).
- Onde paramos (lista de tarefas da sessão do Codespace):
  1. ✅ Correções das 3 rejeições commitadas;
  2. ⏳ **Aguardar resposta da Apple sobre o pedido Unlisted (ticket
     aberto)** — prazo típico 1–7 dias, aberto por volta de 04/06;
  3. ⬜ **Quando o Unlisted for aprovado: gerar build novo e resubmeter
     à App Store.**
- **Verificado em 11/06**: o app NÃO está publicado (busca pública da
  Apple pelo app ID 6774250898 e pelo bundle `com.wizmart.promotor`
  retorna vazio) e **nenhuma issue automática veio de iPhone** (nenhum
  promotor usa iOS ainda).
- ❓ Lacuna: não sabemos se a Apple respondeu o ticket Unlisted desde
  04/06. Onde conferir: e-mail da conta Apple Developer (mensagens de
  "App Review"/"App Store Connect") ou o painel appstoreconnect.apple.com.

## Linha do tempo

| Data | Evento |
|---|---|
| 25–26/05 | Estrutura `ios/` criada + `codemagic.yaml` (pipeline CI) |
| 28/05 | Port "tecnicamente finalizado"; primeiros builds reais no Codemagic (ajustes de certificado/assinatura) |
| 31/05 | App marcado iPhone-only (Apple exigia screenshots de iPad para submeter) |
| 01/06 | **Submissão à App Store + pedido Unlisted** (build #12) |
| 03/06 | Rejeição "crash on launch" corrigida (registro dos BGTasks do workmanager no AppDelegate) |
| 03/06 | Correções de permissão (diretriz 5.1.1: respeitar negação; GPS opcional fora de /visita) |
| 04/06 | **3ª rejeição** corrigida (botão "Conceder Permissão" → "Continuar", diretriz 5.1.1(iv)) |
| 04/06→ | Aguardando ticket Unlisted; nenhum commit iOS desde então |

## Conta e identificadores

- Team: **JP SMART VENDING OPERADORA DE MAQUINAS AUTOMATICAS LTDA**
- Bundle ID: `com.wizmart.promotor` · App Store Connect app ID: 6774250898
- Versão 1.0 toda configurada no App Store Connect via API (descrição
  pt-BR, categoria Business, preço FREE/BRA, privacy details, screenshots
  6.7", credenciais de demo para o reviewer).
- Credenciais (Issuer ID, Key ID, chave .p8, demo) **não estão no repo**
  (repo é público) — estão na memória do Codespace e na UI do Codemagic
  (grupo `wizmart-secrets`, integração `app_store_connect`, role Admin).

## Esteira de build (fatos)

- `codemagic.yaml` (workflow `ios-testflight`, mac_mini_m2, Flutter
  3.41.9): gera `.ipa` assinado e sobe para o App Store Connect.
  `submit_to_testflight: false` (build não segue ao TestFlight).
- ⚠️ **O webhook do Codemagic NÃO dispara nos pushes na prática** (motivo
  desconhecido, registrado na memória do Codespace), apesar de o yaml
  configurar trigger por push. Builds são disparados **manualmente ou via
  API** (`POST /builds` com appId + workflowId + branch; token em
  Codemagic → Settings → Integrations → Codemagic API).
- Consequência: o comportamento real já é "publicação só sob demanda",
  como o Alan definiu — a correção do yaml (remover trigger por push,
  dev→TestFlight) formaliza isso.
- `CERT_PRIVATE_KEY` (env persistente no Codemagic): NÃO regenerar a cada
  build — a Apple limita certificados de distribuição e cada um é casado
  com uma chave específica.
- Pegadinhas resolvidas e detalhes finos: ver
  `docs/memoria-codespace/project_ios_port.md`.

## Regra de publicação (definida pelo Alan, 11/06/2026)

- Publicação iOS **somente mediante solicitação do Alan** — nunca
  automática por push.
- Pedido de **teste na `dev`** → build da `dev` vai para o **TestFlight**.
- Publicação a partir da `main` → **App Store (distribuição Unlisted)**,
  conforme o caminho já em andamento.

## Próximos passos

1. Conferir resposta da Apple ao ticket Unlisted (e-mail ou painel).
2. Cadastrar nas variáveis de ambiente do Claude Code: token da API do
   Codemagic e chave da App Store Connect (sessões novas as enxergam) —
   permite acompanhar/disparar tudo daqui.
3. Quando o Unlisted estiver aprovado: disparar build novo (com as
   correções de 03–04/06) e resubmeter.
4. Ajustar `codemagic.yaml` à regra de publicação (sob demanda;
   dev→TestFlight) — só após credenciais e verificação do histórico de
   builds.
