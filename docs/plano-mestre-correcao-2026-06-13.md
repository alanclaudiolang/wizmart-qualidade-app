# PLANO MESTRE de correção — 13/06/2026 (nada fica para depois)

> Consolida TUDO o que foi identificado nesta semana: 6 causas-raiz + 3
> gaps achados no cruzamento dos issues + a incoerência do Finalizar + o
> ponto cego de telemetria + correção dos históricos no servidor + iOS +
> exposições de dados. Cada item tem solução concreta e risco. Não há
> nenhum item "anotado para depois" — por decisão do Alan (13/06).
> Detalhamento técnico em: `analise-arquitetural-2026-06-13.md` (mapa de
> escritas), `cobertura-bugs-semana-2026-06-13.md` (gaps),
> `proposta-correcao-completa-2026-06-12.md` (riscos item a item).
> **Nada implementado ainda — aguarda OK do Alan (regra 3a).**

---

## BLOCO 1 — Build Android (código) · UM BUILD DEFINITIVO, com force-update

**Requisito do Alan (13/06): este é o build DEFINITIVO — não passar várias
versões. Os 15 itens vão TODOS juntos, validados no `v-dev` antes de
produção.**

Risco p/ quem está em versão anterior, em TODOS os itens deste bloco:
nenhuma mudança toca galeria nem dados já gravados; quem está em build
antigo segue exposto ao bug até o force-update instalar (horas). Nível por
item: 🔴 alto / 🟠 médio / 🟢 baixo.

| # | Causa/Gap | Problema (1 linha) | Solução | Risco |
|---|---|---|---|---|
| 1 | **A** pivot | O número interno da visita troca com a tela aberta → fotos caem no id morto (somem, Finalizar no vácuo, órfãos) | Adiar a consolidação enquanto a visita está em uso (`LastVisitaService`/`ProcessingTracker`/`watermark_pending`), com timeout de segurança de 2h | 🟠 |
| 2 | **A** cinto | Escritas da tela no id velho falham silenciosas (0 linhas) | Helper único: toda escrita que afetar 0 linhas re-resolve o serverId (mapa gravado na consolidação) e reaplica; só age quando o id casa gabarito\|pdv\|turno\|data | 🔴 |
| 3 | **A** raw | Carimbo apaga o arquivo cru mesmo quando não trocou o caminho no JSON (grade quebra) | Só apagar o cru DEPOIS de confirmar a troca no JSON; re-resolver id migrado em `_trocarPathNoJson` | 🟢 |
| 4 | **A4** dedup | Arrays com URLs duplicadas (refazer gera 2º conjunto) | `getUploadedPhotoUrls` passa a devolver URLs distintas preservando ordem — em Dart, **sem mexer no schema** | 🟢 |
| 5 | **B** largada | Iniciar no instante da sincronização apaga a abertura | Reset do passo 6 do pull vira UPDATE condicional atômico (`WHERE abertura IS NULL AND synced AND status=1`) | 🟠 |
| 6 | **B** pausa | Sincronização roda na tela da visita fora da captura | Pausar sync em TODA a tela da visita; `fullSync` re-checa a pausa entre push e pull | 🟢 |
| 7 | **C** fantasma | Guard apaga visita com fotos/em-andamento quando falta abertura | Só descartar com ausência TOTAL de trabalho; havendo trabalho e abertura nula, INSERT com `abertura := createdAt da 1ª foto SE for de hoje`, senão `now()` | 🟠 |
| 8 | **D** lock | Trava entre processos expira (240s); WorkManager entra em paralelo | Renovar a trava por lote (reescrever `lastPullAt`); WorkManager passa a fazer só `processOutbox` (push) | 🟠 |
| 9 | **E** sessão | Sessão morta (403) → fotos param e o aviso é fraco | Aviso de relogin persistente até resolver (cobre também tela de visita aberta); nunca subir com `authUid` vazio (path com segmento vazio) | 🟠 |
| 10 | **GAP1** crash foto | `setState` em `_tirarFoto:520` após o Android matar a tela com a câmera aberta → "Null check" | `if(!mounted) return` antes de cada `setState` pós-`await` em `_tirarFoto`, `_concluirFotosDepois`, `_finalizarVisita` | 🟢 |
| 11 | **GAP3** boot-521 | App pode falhar no boot quando o servidor está fora (Cloudflare 521) | Envolver o refresh de sessão do boot em try/catch que degrada para offline | 🟢 |
| 12 | **H** finalizar | Finalizar trava a tela esperando o servidor (fere offline-first) | Finalizar local e ir pra home na hora; envio em background; **pull nunca rebaixa visita com post pendente** (regra do Alan); card mostra "Realizada + enviando" | 🟠 |
| 13 | telemetria | `D4` é cego para a Causa A (órfãos descartados antes da conta) | Emitir anomalia quando o guard de ÓRFÃO descartar fotos (`sync_engine.dart:1060`) — para nunca mais a perda por pivot passar invisível | 🟢 |
| 14 | **A2 visita "em andamento" rebaixada** (achado no relato Felipe #2441, 13/06) | O app NÃO consegue subir o status "Em Andamento" (2) ao servidor: `_filtrarPayloadMinimo` (`sync_engine.dart:856-861`) só deixa passar status 1/5. Então o servidor nunca fica "em andamento". Quando o `open` sobe e a visita vira `synced`, o **pull a PURGA** (`deleteVisitasSincronizadasSemPendencias`) e a **recria como AGENDADA** (servidor não tem o "em andamento") → volta pra tela "Iniciar visita" e zera o `fotosAntesJson` local. As fotos antes só não se perdem se já tiverem subido (sorte de timing). | A proteção do pull (regra do Alan/item 12) passa a ser por **trabalho em andamento** — `statusVisita=2` OU `localState` não-terminal — e NÃO só por `syncStatus='pending'` (após o `open`, a visita fica `synced` mas ainda está em execução). A purga e a recriação NUNCA tocam visita com execução em curso. | 🔴 |
| 15 | **observabilidade** (requisito do Alan, 13/06) — log cego para ações de UI | O log atual registra só sync/foto, NÃO os toques/navegação do promotor. Por isso, no caso Felipe, o log "parou" e a sequência do reinício ficou invisível — tive de inferir pela anomalia temporal | `PersistentLogger` passa a carimbar com data/hora CADA interação do usuário na tela de visita: clicar Iniciar, tirar/remover/reordenar foto, concluir antes/depois, voltar, descartar etapa, finalizar, REABRIR visita + cada transição de `localState`/`statusVisita`. Assim qualquer caso é reconstruível sem adivinhação | 🟢 |

> **A2 é grave e foi confirmada por anomalia temporal:** na 122556 (Felipe),
> `dia_hora_abertura`=13:11 é POSTERIOR a `dia_hora_fotos_antes`=12:49 —
> impossível sem reinício. O promotor foi forçado a reiniciar a visita; só
> não perdeu o antes porque as 7 fotos já haviam subido ao servidor às
> 13:07 (rede voltou pouco antes do pull rebaixar). Em rede pior, seria
> perda real. NÃO estava nas 6 causas — descoberta na leitura do relato.

**Itens 🔴 (id/consolidação):** só 2 e 7 têm componente sensível; o item 1
(adiar) faz a PK não mudar sob os pés do escritor, o que reduz muito a
dependência do 2. Todos com teste que reproduz o bug no código atual ANTES
de corrigir, e validação no canal `v-dev` (lado a lado) antes de produção.

**Decisão sobre a "Arquitetura 2" (id local nunca muda):** NÃO é pendência.
É uma decisão consciente de **não** reescrever o pull agora — o item 1
resolve a Causa A de raiz (a PK não migra enquanto há escritor) com risco
muito menor. A Arquitetura 2 só entraria se o item 1 se mostrasse
insuficiente nos testes; não fica "para depois", fica descartada salvo
evidência em teste.

---

## BLOCO 2 — Correção dos históricos no servidor (Supabase, UPDATE only)

Feito SÓ depois do build em campo (senão um app antigo reescreve), com OK
do Alan e backup antes de cada UPDATE. Lista fechada de alvos:

| Visita | Promotor | Problema | UPDATE proposto |
|---|---|---|---|
| 122527 | Diego (119) | `fotos_depois` com 4 URLs duplicadas | dedup do array, preservando ordem |
| 122383 | Renato (49) | `fotos_antes` com 4 duplicadas | dedup do array |
| 122384 | Renato (49) | `fotos_antes` com 7 duplicadas | dedup do array |
| 8 visitas 08–09/06 | Felipe (34) | arrays com 4–8 duplicadas cada | dedup de cada array |
| 122381 | Renato (49) | sem `dia_hora_abertura` (anomalia) | setar abertura pela 1ª foto/realizado |
| 119980, 119966 | Felipe (34) | sem abertura | idem, conferindo marca d'água |
| órfãos `…//visita-…` no bucket | vários | arquivos fora de array (uid/data vazios) | identificar e remover do bucket (não da galeria) |

Antes de cada um: conferir a marca d'água (OCR) das fotos vs as 5 datas da
visita (regra "anomalia temporal"). Nenhuma exclusão de registro — só
UPDATE/limpeza de array e remoção de arquivo órfão do bucket.

---

## BLOCO 3 — Operacional (sem código)

1. **Builds antigos (<196) presos** (Franciele/186 e outros): varrer os
   cartões `[ESTADO]`, listar quem está abaixo de 196, e mandar o link
   fixo do APK por WhatsApp (instala por cima, não perde nada). A
   pendência drena com Wi-Fi + Sair→entrar (mesmo e-mail).
2. **Renato — rota sem visitas:** gabaritos da rota vencidos (prazo de
   validade) — renovar no cadastro (administrativo).

---

## BLOCO 4 — iOS (GAP 2, crash build 19 #642)

Crash "Null check" no boot/home da versão iOS. Como o iOS não tem
auto-update, e a publicação está parada aguardando o ticket Unlisted da
Apple (ver `docs/publicacao-ios.md`): a correção (mesma classe de guard do
item 10) entra no mesmo código; quando a Apple liberar e gerarmos build
iOS novo, já vai corrigido. Não há ação de campo possível antes disso.

---

## BLOCO 5 — Exposições de dados (repo é PÚBLICO)

1. **Nomes/e-mails de promotores em docs e issues:** anonimizar os docs
   versionados (usar id em vez de nome/e-mail) e avaliar tornar os issues
   `[ESTADO]`/`[USUÁRIO]` privados ou sem PII. Risco: nenhum para o app.
2. **Anon key do Supabase hardcoded** (`app_constants.dart:6`): é a chave
   ANON (já pública por design do Supabase, protegida por RLS) — não é
   segredo, mas convém confirmar que o RLS bloqueia escrita indevida.
   Verificar e documentar; não bloqueia nada.

---

## Sequência de execução (com OK do Alan a cada publish — regra 3a)
1. Build Android: itens 1–13 no mesmo build, cada um com teste que falha
   no código atual; validar no `v-dev`; APK 249 guardado como rollback.
2. Publicar com `[FORCE-UPDATE]` (com OK explícito naquele momento).
3. Bloco 3 (operacional) em paralelo — independe do build.
4. Bloco 2 (históricos) depois do build em campo, item a item com OK.
5. Bloco 5 (exposições) — sem urgência, sem risco para o app.
6. iOS (Bloco 4) quando a Apple liberar.
7. Atualizar `docs/fluxo-e-gatilhos-app.md` no commit do build (regra 7).
