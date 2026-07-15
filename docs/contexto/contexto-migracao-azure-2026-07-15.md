# Contexto da migração para o Azure DevOps — 15/07/2026

> Documento de estado. Qualquer sessão futura deve conseguir retomar o
> trabalho lendo ESTE arquivo + o CLAUDE.md + o mapa técnico
> (`docs/fluxo-e-gatilhos-app.md`).

## Por que migramos

A conta GitHub `alanclaudiolang` (login `alanclaudiolang-rs`) foi
**suspensa por "violação de ToS"** (~24/06/2026), sem explicação
detalhada. Consequências: release `v-latest` 404 (download/auto-update dos
promotores FORA DO AR), commits de 20–24/06 inacessíveis, CI (GitHub
Actions) morta, secrets (keystore!) inacessíveis. O Alan perdeu a
confiança no GitHub e decidiu migrar para o **Azure DevOps**
(org `smartcafe`, projeto `wizmart`).

### Situação da conta GitHub
- 2 chamados abertos no Support (~26/06, PT + EN) + formulário oficial de
  reinstatement preenchido em 15/07 (prazo de apelação: 6 meses).
- Se a conta voltar: os commits reais de 20–24/06 servem de CONFERÊNCIA da
  reconstrução (ver abaixo); nada mais depende do GitHub.
- Códigos de recuperação 2FA do GitHub: o Alan possui (não resolvem
  suspensão; servem para o login quando a conta voltar).

## O que existe no Azure DevOps (dev.azure.com/smartcafe/wizmart)

| Recurso | Conteúdo |
|---|---|
| Repo `wizmart-qualidade-app` | Código completo. `main` = estado 19/06; branch `claude/azure-devops-integration-5ghp7w` = reconstrução do build 260 (deep link) + config de build |
| Repos `wizmart-app-flutterflow` / `wizmart-web-flutterflow` | Placeholders (README) — o código FlutterFlow vive na plataforma FlutterFlow |
| Secure Files | `wizmart-upload-2026.jks` — keystore NOVA de assinatura Android (gerada 15/07; a original ficou presa nos secrets do GitHub) |
| Variable group `android-signing` | `UPLOAD_KEY_ALIAS=upload` + senhas da keystore (secretas) |

⚠️ **Histórico git**: o clone disponível era raso — o histórico começa em
11/06/2026 (60 commits) e os SHAs foram reescritos na migração (conteúdo,
datas e mensagens idênticos). Commits anteriores a 11/06 só existem no
GitHub suspenso.

## Estado do app em campo (15/07)

- **Build 262 (v1.0.2)** é o que está nos celulares — **CONFIRMADO em
  15/07 extraindo o BUILD_TIME do binário de um aparelho: 24/06/2026
  09:25**. Contém o deep link (build 260) + a reordenação do sincronismo
  (visita mais recente primeiro). A release publicou e os promotores
  atualizaram ANTES da suspensão derrubar o link. (Registro de erro: a
  sessão de 15/07 chegou a afirmar "o 262 nunca publicou" com base na
  leitura do histórico — o relato do Alan estava certo e o binário
  provou; a reordenação está testada em campo desde 24/06.)
- Promotores com o app instalado **seguem trabalhando** (o app sincroniza
  com o Supabase). O que está quebrado: download de novas instalações e
  auto-update (apontavam pro GitHub) e o botão de download do site
  (FlutterFlow web → `qualidade.wizmart.com.br`).

## Reconstrução do build 262 (concluída em 15/07)

Ver **`docs/reconstrucao-build-260-2026-07-15.md`** (fontes, fidelidade,
riscos, cobertura de leitura 7a — o doc nasceu mirando o 260; o campo
provou ser 262 e a reordenação foi incluída em seguida). Resumo: deep
link `wizmartapp://wizmartapp.com` + rotas `/loginautomatico` e
`/recoverpassword` + `login_flow.dart` (proteção de troca de conta) +
supabase_flutter 2.12.4 (versões idênticas às do binário, conferidas) +
**reordenação do sincronismo** (getPendingPhotos/getPendingOutboxItems:
`COALESCE(dia_hora_realizado, dia_hora_agendado) DESC` + `created_at`
ASC — espec. exata no histórico exportado). Commits `679752e` e
seguintes na branch de trabalho. flutter analyze 0 erros; suíte
**49/49 verde** (mesmo placar do 262 original). Fontes da reconstrução: APK real do 260 (extraído de celular)
+ histórico exportado (`docs/contexto/historico-sessao-2026-06-19a26.md`).
Pontos de interpretação a validar listados no doc de reconstrução; o
export da sessão de 23/06 (deep link original), se aparecer, é a
conferência final.

## Distribuição (decisões do Alan em 15/07)

1. **Curto prazo (URGENTE)**: APK assinado com a keystore nova, hospedado
   no **Supabase Storage** (bucket `Arquivos`, pasta `versoes-apk/` —
   upload anônimo é PERMITIDO pelas policies atuais; delete/overwrite NÃO,
   então cada versão tem nome próprio, ex. `promotor-wizmart-build263.apk`).
   Atualizar o botão do site (FlutterFlow → Launch URL) para o link novo.
2. **Definitivo**: **Google Play** (conta `plataformawizmart@gmail.com`,
   pessoa jurídica, antiga → sem exigência de teste fechado de 14 dias;
   review de produção ~1–7 dias). App será publicado DO ZERO (novo pacote
   na loja). Pendências: ficha da loja, política de privacidade (URL),
   declaração de dados, AAB assinado.
3. **Consequência da keystore nova**: quem tem o build 260 instalado NÃO
   consegue atualizar por cima (assinatura diferente) — precisa
   desinstalar/reinstalar UMA vez, e desinstalar apaga o banco local.
   REGRA: só orientar a troca com o trabalho 100% sincronizado (fotos com
   marca d'água ficam na galeria — nunca apagar). Quem instala novo pelo
   link/Play não sente nada.
4. Auto-update interno do app (version_check_service) ainda aponta pro
   GitHub (morto) — inofensivo (falha silenciosa), mas o mecanismo precisa
   ser reapontado (Supabase ou Play) num build futuro.

## Build local / CI

- Não há pipeline no Azure ainda (próximo passo). Build feito manualmente
  na sessão: Flutter 3.44.6 + Android SDK (cmdline-tools, platform 35,
  build-tools 34) + keystore do Secure Files.
- `services.gradle.org` e downloads de release do GitHub retornam 403 no
  ambiente de sessão — o wrapper usa mirror da Tencent com
  `distributionSha256Sum` FIXADO (verificado contra 2 mirrors
  independentes). Em agentes do Azure Pipelines isso não é necessário,
  mas o pin não atrapalha.
- dart-defines do build: `APP_VERSION`, `BUILD_TIME`, `BUILD_NUMBER`
  (263 = primeiro build pós-migração), `GITHUB_BUG_TOKEN` (vazio agora —
  telemetria de issues desativada até decidirmos o substituto; os reports
  de erro falham silenciosamente).

## Supabase (nada mudou — e não deve mudar sem OK)

Projeto `czvrbntewaisegvjdzyj`. Deep link: Redirect URLs
(`wizmartapp://wizmartapp.com/*`) e templates de e-mail configurados pelo
Alan em junho — PRESERVADOS no servidor (conferir allowlist quando
possível). A correção de dados de 20/06 (136 visitas sem
`dia_hora_realizado`) está aplicada.

## Pendências (ordem de prioridade)

1. APK no Supabase Storage — versão VÁLIDA (15/07): **build 263**
   (v1.0.2 = conteúdo do 262 de campo: deep link + reordenação do sync),
   PUBLICADO em 15/07 pelo pipeline `build-apk-android` (run 21):
   `https://czvrbntewaisegvjdzyj.supabase.co/storage/v1/object/public/Arquivos/versoes-apk/promotor-wizmart-v1.0.2-build263.apk`
   — SHA-256 `85cedef41b0b98e784faab04d415d93bdaca0c98eef4474e2b7b407fbd410eae`,
   BUILD_TIME embutido 15/07/2026 15:15. Assinado com a keystore
   `wizmart-upload-2026.jks` (fingerprint do cert SHA-256
   `09b18e7a5b3c0aa8544366a94a3541bba51853d4e13bf453cb706a342169f850`;
   cópia de recuperação COM O ALAN + Secure Files; senhas no variable
   group `android-signing`). ⚠️ Secure Files NÃO permite exportar o
   arquivo de volta (só pipelines usam) — a cópia do Alan é o único
   backup exportável. Órfãos do Storage APAGADOS em 15/07 (via
   service_role). **URL FIXA no ar** (Alan decidiu manter link imutável;
   Google Play DESCARTADA em 15/07):
   `https://czvrbntewaisegvjdzyj.supabase.co/storage/v1/object/public/Arquivos/versoes-apk/promotor-wizmart.apk`
   — hoje serve o build 263; builds futuros SOBRESCREVEM esse nome via
   pipeline com a service_role key (variable group `supabase-distribution`,
   id 4, autorizado pro pipeline 3; a chave também está na env da sessão
   como SUPABASE_SERVICE_KEY). FALTA: Alan atualizar o botão do site
   (FlutterFlow → ação Launch URL) para a URL FIXA acima; reenviar o zip
   do APK 262 de campo para arquivar como
   `versoes-apk/promotor-wizmart-v1.0.2-build262-campo.apk` (build
   anterior — único assinado com a keystore original); e OK pendente para
   o build 264 (auto-update reapontado do GitHub para latest.json no
   Supabase — proposta feita, aguardando aprovação).
2. Validar deep link em aparelho real (link do e-mail abre o app?).
3. Pipeline de build no Azure Pipelines (usar Secure Files + variable
   group `android-signing`).
4. Google Play: ficha, política de privacidade, AAB, teste interno →
   produção.
5. Bugs ADIADOS documentados: `dia_hora_realizado` sumindo na consolidação
   (causa mapeada, não reproduzida); câmera do Diego (`retrieveLostData`
   ausente); reordenação do sync (build 262, não testada).
6. Telemetria de issues (substituto do GitHub Issues) — decidir destino
   (Azure Boards? Supabase?).
7. Apelação do GitHub em curso — conferir e-mail periodicamente.
