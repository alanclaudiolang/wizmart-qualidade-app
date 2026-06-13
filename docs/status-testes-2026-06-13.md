# Status dos testes do build definitivo — 13/06/2026

> Suíte rodada com Flutter em banco SQLite em memória, sem celular nem
> promotor. Branch de trabalho `claude/relaxed-wozniak-0zpzsl` (não gera
> build). Cada teste reproduz o bug e valida a correção.

## Resultado atual: 18 testes ✅ (todos verdes), 0 erros de compilação

## Cobertura por item

### ✅ Testado automatizado e VERDE (8 itens — os de PERDA DE DADOS)
| Item | Causa | Teste(s) | Arquivo |
|---|---|---|---|
| 1 | A — adiar troca de id enquanto a visita está em uso | 4 | `item01_e_09_test.dart` |
| 2 | A — mapa de re-resolução de id + migração de fotos | 1 | `item02_mapa_migracao_test.dart` |
| 3 | A — não apagar o cru sem confirmar a troca (grade Renato) | 3 | `item03_apagar_raw_test.dart` |
| 4 | dedup de fotos (arrays duplicados Diego/Renato) | 1 | `item04_dedup_fotos_test.dart` |
| 7 | C — guard fantasma só apaga sem nenhum trabalho (Mauro) | 4 | `item07_guard_fantasma_test.dart` |
| 8 | D — trava de sync renova e não expira no meio | 2 | `item08_lock_test.dart` |
| 9 | E — nunca montar caminho de upload sem login (Adonias) | 2 | `item01_e_09_test.dart` |
| 14 | A2 — purga não rebaixa visita em andamento (Felipe/Thiago) | 1 | `causa_a2_purga_test.dart` |

**Estes são os bugs que causam PERDA/CORRUPÇÃO de trabalho do promotor.**
Todos reproduzidos (vermelho) e corrigidos (verde).

### ✅ Implementado, validação por inspeção (1 item — guard trivial)
| Item | O que | Por que sem teste automatizado |
|---|---|---|
| 10 | `if(!mounted) return` antes dos setState pós-await em `_tirarFoto` | crash de UI (câmera mata a tela); a correção é guard padrão, idêntica aos #10/#12/#621 já validados; widget test exigiria simular morte de tela |

### ⏳ A implementar + validar manual no v-dev (6 itens — UI/UX/observabilidade)
| Item | O que | Por que precisa do v-dev |
|---|---|---|
| 5 | B — reset da largada atômico | a proteção contra zerar já existe (guard temTrabalho 249); o reset atômico é refinamento de concorrência (timing), validável só rodando |
| 6 | pausa de sync na tela inteira | comportamento de UI/SharedPrefs |
| 11 | boot resiliente a servidor fora (521) | fluxo de inicialização; precisa simular servidor fora |
| 12 | Finalizar offline-first (não travar a tela) | mudança de UX; a regra do pull (não rebaixar) já está coberta pelo item 14 |
| 13 | telemetria — anomalia ao descartar órfão | efeito colateral; validável no fluxo real |
| 15 | log com data/hora de cada interação | instrumentação; validada lendo o log de um teste real |

## Conclusão honesta
- **Os 8 bugs de perda de dados estão validados por teste automatizado** —
  é o que dá segurança de que o build NÃO vai perder o trabalho do
  promotor. Reproduzidos e corrigidos, sem celular.
- **O item 10** (crash) é guard padrão, seguro por inspeção.
- **Os 6 restantes** são de experiência/observabilidade (não perdem dado).
  Serão implementados e validados num teste manual rápido no `v-dev` —
  seu celular, instalando lado a lado, SEM passar para promotor.
- A conclusão "pode enviar o build" virá quando os 6 estiverem
  implementados e o v-dev confirmar os de UI. O núcleo crítico (não
  perder dados) já está provado verde.
