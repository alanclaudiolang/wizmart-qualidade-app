# Log de recuperação manual — Edilson (prom 19), 15/06/2026

> Recuperação de visitas FALTA/Incompleta do Edilson Ciriaco da Silva
> (id 19, RJ) a partir das fotos originais da galeria dele (enviadas por
> WhatsApp, 96 fotos). Procedimento: `feedback_recuperacao_manual_procedimento.md`
> + regra Completa/Incompleta `feedback_status_incompleta_definicao.md`.
> Só UPDATE (visitas já existiam como falta); backup antes em
> `/tmp/backup_edilson_20260615/visitas_backup.json`; chave de serviço;
> conferência por OCR depois. Galeria do promotor intocada.

## Decisões-chave
- **Fonte da verdade = marca d'água.** As 96 fotos foram lidas (OCR
  Tesseract no rodapé). **75 têm a 3ª linha "FOTO Antes/Depois - data"**
  (slot confiável); **21 não têm** (fotos de prateleira em paisagem) —
  por decisão do Alan, **essas 21 NÃO foram subidas** (não dava pra saber
  antes/depois sem chutar).
- **Status pela regra documentada** (categoria inteira ausente = Incompleta):
  visita com antes≥1 E depois≥1 → 1 (Concluída); só antes ou só depois →
  5 (Incompleta). Nunca carimbar 3.
- Ordem das fotos em cada slot = ordem cronológica da marca d'água.
- Caminho determinístico: `abastecimentos/<uid Edilson>/<data>_05-00-00/
  <nome>-<hash SHA1(gab|pdv|turno)>-<slot>-<n>.jpg`.

## Resultado (7 visitas, 53 fotos subidas) — conferido
| Visita | PDV | Dia | Antes | Depois | Status |
|---|---|---|---|---|---|
| 121710 | VIX COMERCIO | 11/06 | 4 | 5 | 1 Concluída |
| 121697 | SOMA SÃO CRISTOVÃO | 11/06 | 2 | 4 | 1 Concluída |
| 122701 | PALAZZO | 12/06 | 4 | 5 | 1 Concluída |
| 122702 | DOM MAURICIO | 12/06 | 2 | 4 | 1 Concluída |
| 122727 | LEV BICICLETAS | 12/06 | 5 | 6 | 1 Concluída |
| 122753 | AMBEV CENTRO | 12/06 | 5 | 5 | 1 Concluída |
| 121698 | CONCREMAT | 11/06 | 2 | 0 | **5 Incompleta** |

- **CONCREMAT** ficou Incompleta porque, das 12 fotos dele, 10 não tinham
  a linha de slot e só 2 (ambas "Antes") puderam ser subidas com certeza.
- Conferência: todas as 53 URLs respondem 200; OCR de amostra confirmou
  que o slot do caminho bate com o slot da marca d'água em todas.

## 3 visitas já Concluídas (LENNY/CACAY/TACO) — comparadas, SEM substituição
LENNY 121068, CACAY 121229, TACO 122833. O Edilson mandou a galeria do dia
inteiro, então elas também vieram no zip. Comparei **pelo horário da marca
d'água** (identidade da foto) posição a posição:
- **TACO**: 4 antes + 4 depois — todas IGUAIS às do bucket.
- **CACAY**: 5 depois iguais; 2 antes iguais (+2 antes do bucket que o OCR
  não leu o horário, mas as demais batem).
- **LENNY**: 4 depois iguais; 3 antes iguais + 1 antes a MAIS já no bucket
  (08:20:39) que não veio no zip.
Conclusão: o trabalho dessas 3 **sincronizou normalmente** — o bucket já
tem as originais. Substituir só colocaria cópias do WhatsApp (qualidade
pior) das mesmas fotos. **Decisão do Alan (15/06): deixar como estão.**

## As 21 fotos sem slot — fora (decisão do Alan: não subir)
Não têm a 3ª linha "FOTO Antes/Depois" na marca d'água, então não dava
para saber antes/depois sem chutar. Relação completa no histórico da
conversa. Consequência: CONCREMAT ficou Incompleta (só "antes").

## Status final: CASO ENCERRADO ✅
