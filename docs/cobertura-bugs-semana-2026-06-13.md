# Cobertura: bugs da semana (08–13/06) × proposta de correção

> Cruzamento de TODOS os issues da semana (relatos de promotor, crashes
> automáticos e anomalias D1–D6) + os sintomas descritos no chat, contra
> as 6 causas-raiz da proposta. Objetivo: achar o que NÃO está coberto.
> Dados verificados via busca no GitHub em 13/06.

## Volume da semana (fatos)
- **32 relatos de promotor** (`user-report`): 31 na home, 1 em realizado.
  Promotores: Franciele(8), Felipe(5), Luís Rafael(3), Camila(3),
  David(2), Adonias(2), Mauro(2), + Jéssica, Thamara, Thiago, SP06,
  Gabriel, Alan-teste. **Todos sem texto** (o app manda só log+sondas) —
  o sintoma vem do chat/logs, não do título.
- **2116 anomalias automáticas**: esmagadora maioria `D5`
  (visita realizada local mas não sincronizou). `D4` e `D6` = **0** na
  semana.
- **7 crashes automáticos**: 5 "Null check" (ref após dispose), 1 iOS
  (build 19), 1 boot com servidor fora (Cloudflare 521).

## Matriz sintoma → causa → coberto?

| Sintoma observado (issue/chat) | Causa-raiz | Coberto pela proposta? |
|---|---|---|
| Foto some da grade (Renato print) | A (pivot) | ✅ item A |
| Visita "volta ao início" (Kian, Camila, L.Rafael, Mauro, Gabriel) | A/B | ✅ A + B |
| Visita zera ao Iniciar (Mauro INTERTEK) | B (corrida largada) | ✅ B |
| Trabalho descartado como fantasma (Mauro) | C | ✅ C |
| URLs duplicadas no array (Diego, Renato) | A4 | ✅ A4 (dedup distinct) |
| Finalizar "no vácuo" / 0 linhas (Mauro, David) | A | ✅ A (re-resolução id) |
| Agenda vazia (Camila) | fila 422 + lock (D) | ✅ corrigido 249 + D |
| Sessão morta 403 RLS (Adonias, Camila) | E | ✅ E |
| Build antigo preso (Franciele, 186) | F | ✅ F (operacional) |
| Renato sem visitas agendadas | gabaritos vencidos | ➖ administrativo (não-código) |
| `D5` em massa (2116) | telemetria (G) | ✅ G (cooldown 1 dia) + razões em D/E |
| `D1` upload erro real | E (RLS) / arquivo | ✅ E |
| `D2` watermark travado | A (pivot) / boot | ✅ A + recovery boot (já existe) |
| `D3` outbox travado | A/D | ✅ A + D |
| Finalizar trava a tela em rede ruim | (incoerência offline-first) | ⚠️ item NOVO H (ver abaixo) |
| Crash Null-check builds 176–227 (#249,#396,#507,#621) | ref após dispose | ✅ guards já nos builds ≥245 |
| **Crash Null-check build 245 `_tirarFoto:520` (#691, Thiago)** | ref após dispose NÃO guardado | ❌ **GAP 1** |
| Crash iOS build 19 (#642) | iOS (plataforma) | ➖ **GAP 2** — separado |
| Crash boot servidor 521 (#690) | erro fatal no boot c/ servidor fora | ⚠️ **GAP 3** — menor |

## GAPS encontrados (o que a proposta de 6 causas NÃO cobria)

### GAP 1 — Crash `setState` em `_tirarFoto` após dispose (build 245) 🔴
`visita_screen.dart:520` faz `setState(() => _savingPhoto = true)` logo
após `_picker.pickImage`. Se o Android matar/recriar a tela enquanto a
câmera está aberta (comum em celular fraco), o widget é disposed e o
`setState` estoura "Null check operator" — crash. Os guards `if(!mounted)`
que adicionamos cobriram `_loadVisita`, **não** este ponto. Mesma classe
dos #10/#12/#13/#621, ponto novo. **Correção:** guard `if(!mounted)` antes
de cada `setState` pós-`await` em `_tirarFoto`, `_concluirFotosDepois` e
`_finalizarVisita`. Risco 🟢 (só adiciona guarda). **Vira item da proposta.**

### GAP 2 — Crash iOS (build 19, #642) ➖ separado
É da versão iOS (TestFlight/Codemagic), não dos builds Android das 6
causas. Já é pendência registrada (`docs/pendencias-2026-06-12.md`).
Tratar no contexto da publicação iOS, fora deste build.

### GAP 3 — Boot com servidor fora (521, #690) ⚠️ menor
Quando o Supabase responde 521 (Cloudflare/servidor fora), um erro de
auth no boot escapou como fatal. O `main.dart` já protege
`Supabase.initialize`, mas o refresh de sessão no boot não. Offline-first
deveria deixar entrar mesmo com servidor fora. **Correção:** envolver o
refresh de boot em try/catch que degrada pra offline. Risco 🟢.

### Item H — Finalizar trava a tela (incoerência offline-first) ⚠️
Discutido no chat: `_finalizarVisita` faz `await processOutbox` quando
online, travando a tela. Fere o offline-first. **Correção:** finalizar
local e sair na hora; envio em background; pull nunca rebaixa visita com
post pendente (regra do Alan: get só sobrepõe status se o post concluiu);
card mostra "Realizada + enviando". Não gera issue (não é erro), mas é
incoerência arquitetural real. **Vira item da proposta.**

## Ponto cego de telemetria (não é bug, é diagnóstico)
O detector `D4-discrepancia-fotos` deu **0** na semana — mas houve perda de
fotos por pivot (Causa A). Motivo: no pivot, as fotos caem no id MORTO e
são descartadas como órfãs ANTES de chegar ao `_buildVisitaPayload`, então
a comparação capturadas×enviadas (que roda no id certo) não as enxerga. Ou
seja: **a telemetria atual NÃO "vê" a Causa A diretamente** — o que
explica por que ela demorou a ser diagnosticada. **Correção (item 13 do
plano mestre, dentro do build):** emitir anomalia quando o guard de ÓRFÃO
descartar fotos (`sync_engine.dart:1060-1069` já loga `Fotos penduradas:
depois=N`). Não fica para depois.

## Conclusão
A proposta de 6 causas cobre **100% dos sintomas de perda/corrupção de
dado** da semana. A análise dos issues acrescentou **2 itens novos**
(GAP 1 crash `_tirarFoto`; item H finalizar offline-first), **1 menor**
(GAP 3 boot-521) e **1 fora de escopo** (GAP 2 iOS). Com esses, a lista
fica completa para o build Android. Nenhum item exige mexer na galeria
nem em dados de versões antigas.
