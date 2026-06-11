# Publicação iOS — status e contexto consolidado

> Consolidado em 11/06/2026 a partir de: memórias recuperadas do Codespace
> (`docs/memoria-codespace/`), histórico de commits do repo e verificações
> feitas em 11/06 (API pública da Apple, codemagic.yaml). Substitui o
> contexto que estava preso no Codespace.

## ⏩ ATUALIZAÇÃO 11/06/2026 ~20:50 UTC — RESUBMETIDO À APPLE

Executado nesta data, sob comando do Alan ("podemos iniciar"):

1. `dev` igualada à `main` (incluiu os 4 fixes de sync de 10/06).
2. **Build #19** disparado via API do Codemagic, concluído e enviado ao
   App Store Connect; processado **VALID** na Apple. Contém a correção
   da 4ª rejeição (botão "Continuar") + fixes de 10/06.
3. `releaseType` da versão 1.0 mudado de AFTER_APPROVAL para **MANUAL**
   (estava configurado para entrar na loja sozinho ao ser aprovado, o
   que violaria a regra do Alan e o Unlisted pendente; agora a
   liberação final é sempre um ato explícito nosso).
4. Submissão antiga (UNRESOLVED_ISSUES, de 03/06) **cancelada**; build
   #19 anexado à versão 1.0; **nova submissão enviada — estado
   WAITING_FOR_REVIEW desde 2026-06-11 20:46 UTC** (5ª submissão).
5. Restou 1 rascunho órfão não-cancelável (`0e754b7a...`), obsoleto e
   inofensivo.

Aguardando: veredito da revisão (típico 24–48h; chega por e-mail
também) e resposta do ticket Unlisted (sem e-mail até 11/06). Quando
aprovado, a liberação na loja é manual e só ocorre sob comando do Alan.
Correções operacionais pendentes do app entrarão em build futuro.

## Status em 11/06/2026 antes da resubmissão (histórico)

- **Versão 1.0 no App Store Connect: estado REJECTED.**
- Houve **4 submissões à revisão** (não 3): 01/06 14:10, 01/06 16:30,
  03/06 05:42 (todas encerradas com rejeição) e **03/06 21:48 — esta
  última está aberta no estado UNRESOLVED_ISSUES** (item REJECTED). É a
  rejeição do botão "Conceder Permissão" (diretriz 5.1.1(iv)), cuja
  correção foi commitada em 04/06 (`8017072`) **mas nunca entrou em
  build nenhum**.
- **Último build: #18 (03/06)** — processado e VÁLIDO na Apple, mas SEM a
  correção de 04/06. Histórico Codemagic: 18 builds, todos da branch
  `dev` (nunca houve build da `main`); #1–8 e #13 falharam, demais OK.
- Existem **2 rascunhos de submissão criados e nunca enviados** no App
  Store Connect (sobras; ids `49a5152f...` e `0e754b7a...`).
- **Pedido Unlisted: não é visível pela API** (é ticket de suporte) —
  conferir resposta no e-mail da conta Apple Developer.
- Verificado em 11/06: o app NÃO está publicado (busca pública vazia) e
  nenhuma issue automática veio de iPhone (nenhum promotor usa iOS).
- Acessos configurados e testados em 11/06 nas variáveis de ambiente:
  `CODEMAGIC_API_TOKEN`, `ASC_ISSUER_ID`, `ASC_KEY_ID`,
  `ASC_API_KEY_B64` (conteúdo do .p8 em base64 numa linha; decodificar
  antes de usar). Ambos funcionando — Codemagic appId
  `6a179b113d152b382b829ed8`, workflow `ios-testflight`.

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

1. ✅ ~~Cadastrar credenciais nas variáveis de ambiente~~ (feito e
   testado em 11/06; nota: as variáveis aparecem inclusive na sessão
   corrente, não só em sessões novas).
2. Conferir resposta da Apple ao ticket Unlisted (e-mail da conta
   Apple Developer — não aparece na API).
3. Sob comando do Alan: disparar build #19 da `dev` via API do Codemagic
   (incluirá a correção de 04/06), anexar à versão 1.0 e resubmeter,
   resolvendo a submissão aberta (UNRESOLVED_ISSUES) e aproveitando/
   limpando os 2 rascunhos órfãos.
4. Ajustar `codemagic.yaml` à regra de publicação (sob demanda;
   dev→TestFlight). O histórico já foi verificado; falta só decidir o
   momento. Obs.: o webhook por push está comprovadamente morto (vários
   pushes em 10–11/06 e nenhum build novo no Codemagic), então não há
   risco de publicação acidental enquanto isso.
