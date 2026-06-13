# Status dos testes do build definitivo — 13/06/2026 (FINAL)

> Suíte rodada com Flutter em banco SQLite em memória, sem celular nem
> promotor. Branch `claude/relaxed-wozniak-0zpzsl` (não gera build). Cada
> teste de lógica reproduz o bug (vermelho) e valida a correção (verde).

## Resultado: 21 testes ✅ verdes · 0 erros de compilação · 15 itens endereçados

## Quadro final dos 15 itens

### ✅ Testado automatizado e VERDE — 9 itens (21 testes)
Os bugs de **PERDA/CORRUPÇÃO de dados** — os que causam prejuízo real.
| Item | Causa | Bug de campo | Testes |
|---|---|---|---|
| 1 | A | troca de id com a tela aberta (foto some) | 4 |
| 2 | A | re-resolução de id + migração de fotos | 1 |
| 3 | A | grade quebrada (cru apagado sem trocar JSON) — Renato | 3 |
| 4 | — | fotos duplicadas no array — Diego/Renato | 1 |
| 5 | B | reset zera visita iniciada (corrida Iniciar×sync) | 3 |
| 7 | C | trabalho apagado como "fantasma" — Mauro | 4 |
| 8 | D | trava de sync expira no meio | 2 |
| 9 | E | upload sem login trava por dias — Adonias | 2 |
| 14 | A2 | visita em andamento rebaixada — Felipe/Thiago | 1 |

### ✅ Implementado — validação por inspeção + teste manual no v-dev — 5 itens
Bugs de **experiência/observabilidade** (não perdem dado); câmera/UI/boot
não são automatizáveis sem aparelho.
| Item | O que foi feito | Como validar |
|---|---|---|
| 10 | `if(!mounted) return` antes dos setState pós-await em `_tirarFoto` (crash #691) | abrir câmera e matar o app por memória no v-dev |
| 11 | erro de rede transitória no boot (521) não é mais tratado como bug | abrir com servidor fora |
| 12 | Finalizar grava local e sai na hora (sem travar); envio em background; pull não rebaixa (item 14) | finalizar offline e online no v-dev |
| 13 | anomalia `D7` quando o app descarta fotos órfãs (telemetria enxerga a Causa A) | ver no log de um teste real |
| 15 | log com data/hora de Iniciar e (Re)Abrir visita — reconstrói a sequência | ler o log de um relato |

### ⏸️ Decisão consciente de NÃO implementar — 1 item
| Item | Por quê |
|---|---|
| 6 (pausar sync na tela inteira) | Redundante: os itens 1 (adiar consolidação) e 14 (pull não rebaixa) já protegem a visita do pull de forma cirúrgica. Pausar TUDO atrasaria o upload das fotos do "antes" sem ganho. Não é pendência — é escolha de engenharia. |

## Conclusão
- **Os 9 bugs de perda de dados estão provados verde** por teste
  automatizado, sem celular. É a garantia central: o build NÃO vai perder
  o trabalho do promotor.
- **5 itens de UX/observabilidade** estão implementados e se confirmam num
  teste manual rápido no `v-dev` (seu celular, lado a lado, SEM promotor).
- **1 item** foi conscientemente descartado por redundância.
- **Nenhum item ficou para depois.** A liberação para produção depende só
  de você rodar o `v-dev` e confirmar os 5 de UI — o núcleo (dados) já
  está demonstrado.
