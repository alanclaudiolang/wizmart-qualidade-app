# Contexto temporário — handoff da sessão de 10-11/06/2026

> **Para a nova sessão do Claude:** leia este arquivo ANTES de qualquer tarefa.
> Ele registra todo o histórico da sessão anterior. Após retomar o trabalho e
> concluir as pendências, este arquivo pode ser removido (é temporário).

---

## 1. Quem é o usuário e como trabalhar

- Alan (alanclaudiolang@gmail.com), dono do repositório.
- Regras permanentes estão no `CLAUDE.md` (raiz): linguagem clara sem jargão;
  mudanças só com base em fatos verificados no código; perguntar antes de agir
  quando faltar elemento; **perguntar antes de qualquer alteração** (issues,
  código, dados).
- Trabalhar **direto na branch `main`** — Alan pediu explicitamente para NÃO
  criar branches/ramificações.
- Alan migrou do VS Code/Codespaces para o Claude Code web por problemas de
  conectividade. O contexto antigo dele ficou preso num Codespace inacessível
  (pasta `~/.claude` — fora do repo, irrecuperável por export). Este arquivo é
  a reconstrução do contexto.

## 2. O que já foi feito na sessão anterior (10-11/06)

1. **Estudo completo do código (100%)** — todos os 43 arquivos Dart (~12.400
   linhas), Android nativo, CI (GitHub Actions + Codemagic), tool de
   recuperação, docs. Conclusões principais na seção 3.
2. **`CLAUDE.md` criado** com as regras de trabalho e mergeado na `main`.
3. **Pasta `bug-reports/` removida da `main`** — era de um fluxo antigo de
   report com GIF (10-14/05), substituído; o código atual envia fotos de bug
   para o bucket `bug-reports` no Supabase, não para o repo.
4. **18 issues encerradas** (#573–#590, como "not planned"): todas as
   `[ANOMALIA]` abertas em 10/06 ANTES da geração do build 225
   (corte: 10/06 10:22:40 UTC, run #225 do workflow `build_apk.yml`).
5. **Branches:** local só existe `main`. No GitHub ainda existem:
   `claude/zealous-turing-91niwc` (morta, Alan deve apagar manualmente — o
   ambiente bloqueia delete de branches claude/*), a branch de export do
   Codespace `codespace-fictional-space-train-...` (só screenshots, pode
   apagar) e `dev` (ATIVA — usada pelo CI para gerar APK de teste, NÃO apagar).
6. **Acesso ao Supabase:** Alan liberou o domínio
   `czvrbntewaisegvjdzyj.supabase.co` na política de rede do ambiente
   ("Default") — **vale para sessões novas**. A sessão anterior não tinha
   acesso (403). A NOVA sessão deve testar logo no início:
   `curl -s -o /dev/null -w "%{http_code}" https://czvrbntewaisegvjdzyj.supabase.co/rest/v1/ -H "apikey: <anon key de lib/core/constants/app_constants.dart>"`
   — esperado: 200.

## 3. Resumo do projeto (estudo 100%)

- App Flutter offline-first para promotores de campo. SQLite local (Drift) é a
  fonte de verdade; Supabase é o destino. Fila de envio ("outbox") com retry
  exponencial. WorkManager sincroniza a cada 15 min.
- Fluxo central da visita (`localState`): idle → fotos_antes (mín 4) →
  fotos_depois (mín 4) → checklist (7 perguntas) → finalizada.
  Status: app 1=agendada 2=andamento 3=realizada 5=falta;
  servidor 1=realizada 2=andamento 5=falta (CUIDADO: assimétrico!).
- Visita criada offline nasce com id negativo determinístico
  (-SHA1(gabarito|pdv|turno)); ao inserir no servidor há consolidação
  idTemp→serverId re-vinculando fotos e outbox. Área EXTREMAMENTE sensível —
  os comentários do código documentam bugs de produção com nome e data.
- Fotos: capturada → `watermark_pending` (fila de carimbo em background) →
  `pending` → `uploading` → `uploaded`. Recovery no boot do app reseta
  estados presos. A fila de carimbo SÓ processa ao concluir etapa ou no boot.
- O app abre issues automáticas neste repo GitHub: crashes (ErrorReporter,
  cooldown 5min/tela), anomalias D1–D6 (AnomaliaReporter, fila local,
  cooldown 10min), relatos manuais (`user-report`) e 1 issue `[ESTADO]` por
  promotor com build+último login. PAT injetado em build (--dart-define).
- Anomalias: D1 upload erro real; D2 foto presa no carimbo >30min; D3 outbox
  travado >2h; D4 visita subindo com menos fotos que o capturado; D5 visita
  realizada local sem confirmar no servidor >1h; D6 falha ao salvar na galeria.
- Inconsistências README vs código: login é por EMAIL+senha (não telefone);
  sync é 15min (não 5); anon key do Supabase está hardcoded e commitada em
  `lib/core/constants/app_constants.dart` (usar essa key para consultas REST).

## 4. Investigação em aberto — caso Jessica Barboza (promotora id 545)

Situação em 10/06: 11 issues abertas dela. Diagnóstico fechado (a partir dos
dumps SQLite embutidos nas issues):

- **D5 em enxurrada** (#595 #597 #598 #603 #606 #608): o celular dela teve
  falha intermitente de internet (erro DNS "Failed host lookup ... errno=7")
  na manhã de 10/06. As 16 fotos da visita -1774743294 subiram OK, mas o
  INSERT da visita falhava e re-tentava com backoff. O alerta D5 re-dispara a
  cada 10min → 1 problema real virou 4+ issues. Auto-resolução provável quando
  a rede estabilizou — CONFERIR no Supabase (seção 5, pendência A).
- **D2 com minutos enormes** (#593: 2900min; #594: 1489min; #601: 1371min):
  fotos de 08-09/06 ficaram presas em `watermark_pending` porque o app foi
  morto antes do carimbo e ela só reabriu o app em 10/06 de manhã (recovery do
  boot então reprocessou — funcionou como projetado, mas 2 dias depois).
- **D2 com minutos pequenos** (#602: 56min; #614: 42min): ALARME FALSO por
  design — a foto fica "watermark_pending" desde o clique da câmera até o
  promotor apertar Concluir; >30min trabalhando dispara o alerta à toa.
- **Suspeita importante:** visita **119092** (08/06, PDV 305 "MM SP - COBRA")
  está local como synced/finalizada, mas com 4 fotos do slot "depois"
  (números 5–8) que ficaram presas 2 dias — provável que no servidor essa
  visita esteja com fotos "depois" faltando e dia_hora_realizado nulo.

## 5. PENDÊNCIAS (executar na nova sessão, nesta ordem)

A. **Conferir no Supabase** (leitura):
   - Visita 119092: campos `fotos_depois` (array) e `dia_hora_realizado`.
   - Visitas da promotora 545 agendadas em 10/06: confirmar se as 5 visitas
     com id temporário negativo (-1774743709, -538250809, -225253080,
     -1774743294 etc.) chegaram (buscar por promotor+data; ids do servidor
     serão outros) e com quantas fotos.
   - Tabela: `visitas`; REST: `/rest/v1/visitas?id_promotor_associado=eq.545...`
   - ⚠️ É BASE DE PRODUÇÃO: apenas SELECT até o Alan aprovar qualquer correção.

B. **Encerrar 9 issues duplicadas/auto-resolvidas da Jessica**
   (#593 #594 #595 #597 #598 #601 #602 #603 #606) — Alan já aprovou a ideia,
   mas CONFIRMAR com ele antes de executar, citando o resultado da etapa A.
   Manter abertas: #608 (até confirmar visita no servidor) e #614 (alarme
   falso recente; fechar se etapa A mostrar tudo OK).

C. **Propor (não implementar sem OK) 2 melhorias anti-ruído:**
   1. D5 não re-reportar quando o último erro do outbox é rede transitória
      (classe `redeTransitoria` do ErrorClassifier) — só reportar erro real.
   2. D2 contar o tempo a partir da CONCLUSÃO da etapa (quando a fila de
      carimbo é de fato acionada), ou subir o limite de 30min; hoje conta
      desde a captura e gera alarme falso.

D. Outros achados em aberto (menor prioridade):
   - Issue #619 (Jeferson, id 590): foto presa há 12 dias (17386 min) —
     investigar igual ao caso Jessica.
   - ~447 issues abertas no total; Alan topou avaliar limpeza por períodos.
   - Branch `claude/zealous-turing-91niwc` no GitHub: Alan apaga manualmente.

## 6. Fatos úteis de referência

- Corte usado p/ limpeza de 10/06: build 225 concluído 2026-06-10T10:22:40Z.
- Issues encerradas: #573–#590 (18, todas [ANOMALIA] pré-build-225).
- Promotores com issues em 10/06 (pós-corte, abertas): Jessica 545 (11),
  Luís Rafael 107 (2 user-report #609 #610), Mauro 412 (#592 #607 D5),
  Franciele 551 (#604 #605 user-report), David 113 (#615 #616 D5),
  Thiago 115 (#599), Caline 452 (#612), Felipe 34 (#613), Paula 134 (#617),
  Glaucia 36 (#618), Jeferson 590 (#619 D2 12 dias), 3 [ESTADO] (#591 #596
  #611).
- O corpo das issues automáticas contém dump do SQLite do celular (estado da
  visita, fotos com URLs, outbox com erros) + 500 linhas de log — dá pra
  diagnosticar muita coisa sem o celular.
