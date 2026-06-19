# Publicação iOS — status e contexto consolidado

> Consolidado em 11/06/2026 a partir de: memórias recuperadas do Codespace
> (`docs/memoria-codespace/`), histórico de commits do repo e verificações
> feitas em 11/06 (API pública da Apple, codemagic.yaml). Substitui o
> contexto que estava preso no Codespace.

## 🔁 ATUALIZAÇÃO 18/06/2026 — 1.0.1 APROVADA, MAS APP CONTINUA INVISÍVEL NA LOJA

A versão **1.0.1 (build 21, com o force-update) foi APROVADA** pela Apple e
está **READY_FOR_DISTRIBUTION** (liberação automática). Porém o app
**continua não aparecendo na App Store pública** (lookup e busca vazios em
br/us). Agora há DUAS versões aprovadas e liberadas (1.0 e 1.0.1) e nenhuma
aparece.

**Diagnóstico reforçado:** o problema NÃO é do build nem da versão (uma
versão nova, recém-aprovada, também não aparece). É falha de disponibilidade
do lado da Apple, no nível da conta/app. Reforça o chamado 102916582924.

**ID do app reconfirmado (a pedido do Alan):** listando todos os apps da
conta — `6774250898` = "Promotor Wizmart" / bundle `com.wizmart.promotor`
EXISTE e é o nosso (bate com os builds do Codemagic). NÃO é ID inexistente.
(Há outros 2 apps na conta, diferentes: 6748234582 "WizMart Uso Interno" /
com.qualidade.wizmart.com.br, e 1540679710 "WizMart" / amlabs.smart247.)

**Follow-up enviado ao chamado 102916582924** com esse novo fato (1.0.1
também aprovada e invisível) para fortalecer o caso.

## 🆕 ATUALIZAÇÃO 17/06/2026 ~19:21 UTC — VERSÃO 1.0.1 (FORCE-UPDATE iOS) SUBMETIDA

Implementado o **force-update do iPhone** (sem Supabase): o app consulta a
versão publicada na App Store pela API pública da Apple
(`itunes.apple.com/lookup?id=6774250898&country=br`), compara com a versão
instalada (`AppConstants.appVersion`) e, se a instalada for MENOR, bloqueia
a tela (login e home, mesmos gatilhos do Android) com botão que abre a App
Store. Código iOS-only (`Platform.isIOS`), fail-open. Arquivos:
`version_check_service.dart` (checkIOS/_versionIsOlder/appStoreUrl),
`auth_screen.dart`, `home_screen.dart`. Commit `36c075d`.

**Pré-requisito de processo:** a comparação é pela STRING de versão (a API
da Apple não expõe build number). Por isso o `pubspec` foi bumpado
`1.0.0 → 1.0.1` (commit `5031e5f`) — **todo release iOS futuro precisa subir
esse número** (1.0.2, 1.0.3…), senão o bloqueio não dispara. Android NÃO é
afetado pelo bump: versionCode vem de `github.run_number` e versionName é
hardcoded no `build_apk.yml`.

**Como o recurso "pega":** a 1.0.1 é a 1ª versão com o force-update; ela
mesma não bloqueia (não há versão mais nova). O bloqueio passa a valer
quando sair a **1.0.2** — aí quem está na 1.0.1 é forçado a atualizar.

**Release:**
- Build **#21** (Codemagic, a partir da `main`; compilou OK = validou o
  código novo) processado VALID na Apple.
- Versão **1.0.1** criada (metadados + 3 screenshots copiados da 1.0
  automaticamente); whatsNew preenchido (obrigatório em updates — foi o que
  causou 409 STATE_ERROR até preencher); `releaseType=AFTER_APPROVAL`.
- **Submetida 17/06 19:21 UTC — WAITING_FOR_REVIEW.**

**Observação:** a aparição na loja continua dependendo da Apple (caso
102916582924 segue aberto sobre a 1.0). Ganho: quando o app aparecer, já
nasce com o force-update. A 1.0 (build 20, sem o recurso) segue
READY_FOR_DISTRIBUTION em paralelo.

## ⚠️ ATUALIZAÇÃO 16/06/2026 ~00:15 UTC — APROVADO MAS NÃO APARECE NA LOJA; CHAMADO ABERTO

Apesar de aprovado/liberado (estado `READY_FOR_DISTRIBUTION`,
`downloadable=true`, Brasil, grátis, sem release futuro/faseado), o app
**NÃO apareceu na App Store pública após ~25h**: a página
https://apps.apple.com/app/id6774250898 retorna "An Error Occurred" e o
app não é encontrado na busca nem no iTunes Lookup/Search API em nenhuma
loja (br, us, pt). Configuração toda verificada — é falha de propagação/
publicação do lado da Apple, sem ação possível pela API.

**Chamado aberto na Apple (Developer → Contato → Distribuição → Outras
perguntas sobre distribuição):**
- **Nº do caso: 102916582924** (conta SMART CAFE / contato@smartcafe.com.br)
- Aberto em 16/06/2026 ~00:14 UTC. Apple responde em até 2 dias úteis
  (por e-mail no contato@smartcafe.com.br).
- Resumo enviado: versão 1.0 (build 20) READY_FOR_DISTRIBUTION há +25h
  mas invisível na loja; pedida investigação/agilização.

**Próximo passo:** aguardar retorno da Apple. Quando responderem (ou se
o app aparecer antes), reverificar o link/busca e seguir a partir daí.
Indicador confiável de que entrou no ar: `itunes.apple.com/lookup?id=
6774250898&country=br` retornar resultado.

## ✅ ATUALIZAÇÃO 14/06/2026 ~22:35 UTC — APROVADO E PUBLICADO

App **aprovado pela Apple e publicado na App Store** (versão 1.0,
build #20). Estado da versão: **READY_FOR_SALE**. Foi a **6ª submissão**
e a primeira aprovada.

O que destravou (executado 13/06):
1. Causa da 5ª rejeição (12/06): **diretriz 2.3.10 — screenshots eram
   reaproveitados do Android e mostravam a barra de navegação do
   Android** ("non-iOS menu bar"). NÃO era código.
2. Build novo **#20** disparado via API do Codemagic a partir da `main`
   (commit de 13/06 "Build definitivo"; mesmo código do APK Android
   build 250). Processado VALID na Apple.
3. **Screenshots reais de iPhone** (login/home/faltas) enviados pelo Alan
   via GitHub (`IMG_5281/5282/5283.png`, 960×2079). Redimensionados aqui
   para **1290×2796** (slot 6.7", display type APP_IPHONE_67) com Pillow
   (Lanczos) e subidos via API substituindo os 3 do Android.
4. Submissão rejeitada (`49a5152f`) cancelada; versão anexada a um
   rascunho (`0e754b7a`) e **submetida** (WAITING_FOR_REVIEW 13/06
   21:21 UTC). Obs.: o `POST reviewSubmissionItems` retorna 409
   transitório logo após o cancelamento — repetir até 201.
5. `releaseType` mudado para **AFTER_APPROVAL** (a pedido do Alan em
   13/06: publicar assim que aprovar, independente do Unlisted; "não tem
   problema aparecer na listagem inicialmente").
6. Apple aprovou entre 13/06 21:21 e 14/06 22:35 → auto-liberou.

Estado em 14/06: **READY_FOR_SALE** (a busca pública pode levar minutos/
horas para indexar — propagação, não bloqueio). Link direto:
https://apps.apple.com/app/id6774250898

Pendências em aberto:
- **Unlisted**: o app nasceu LISTADO (público). Quando a Apple responder
  o ticket Unlisted, aplicar para sair da busca pública sem tirar do ar.
- **Screenshots**: estão em upscale de 960→1290 (qualidade boa, passou).
  Se quiser nitidez máxima no futuro, trocar pelos originais full-res.
- Os `IMG_528x.png` foram removidos do repositório (eram públicos) após
  o uso — ver commit de limpeza.

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
