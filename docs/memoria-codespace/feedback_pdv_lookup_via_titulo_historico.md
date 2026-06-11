---
name: pdv-lookup-via-titulo-historico
description: "Pra associar foto da marca d'água ao PDV: comparar o título OCR LITERAL com visitas.titulo histórico do mesmo (promotor, pdv) — NÃO confiar em concat de api_localCustomerName + api_specificLocation."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5b3db7e3-0a85-41f4-a33b-0441e2dfb1ba
---

**Regra:** ao recuperar visita manualmente cruzando foto-com-marca-d'água
e tabela `pdv`, sempre identificar o PDV correto procurando o título OCR
LITERAL no campo `visitas.titulo` de visitas históricas do mesmo
promotor. NÃO usar heurística de CEP + palavras-chave nem assumir que
`titulo = api_localCustomerName + " - " + api_specificLocation`.

**Why:**
- O usuário ressaltou: pode haver 2 PDVs no mesmo CEP — busca por CEP
  é ambígua. A marca d'água é `pdvNome` que o app define como
  `_visita?.titulo`, ou seja, o `visitas.titulo` exato do servidor.
- O servidor frequentemente persiste um `titulo` que NÃO é a
  concatenação literal de `api_localCustomerName` + `api_specificLocation`.
  Exemplos vistos no David (02/06/2026):
  - pdv 31: `api_localCustomerName = "MM RJ - ED. RIO DE JANEIRO"`, mas
    todas as visitas têm `titulo = "MM RJ - ED. RJ - Centro - Cep 20031-003"`
  - pdv 660 RIOCARD: `titulo` tem NBSP e espaços duplos que não estão
    em `api_localCustomerName`
  - pdv 1671 INTERTECHNE: `titulo` usa `°` (símbolo de grau) e o OCR
    captura `º` (ordinal masculino) — sutilezas tipográficas.
- Resultado prático: heurística por CEP pode mapear PDV errado quando
  há 2+ PDVs no mesmo endereço/CEP. Apenas o match literal título-a-
  título garante 100%.

**How to apply:**
1. OCR extrai linha "PDV: <titulo_literal>" da marca d'água.
2. Buscar no servidor:
   `visitas?id_promotor_associado=eq.<P>&titulo=eq.<titulo_literal>&select=id_pdv_associado`
3. Pegar `id_pdv_associado` da primeira row encontrada.
4. Se zero hits, fallback: buscar `titulo=ilike.<primeiros 50 chars>%`
   pra cobrir truncamento do OCR (tesseract pode cortar com "…").
5. Se ainda zero, aí sim fallback heurístico por CEP — mas reportar
   o caso ao usuário antes de inserir.

**Inserção/atualização:**
- Ao montar payload `visitas`, usar o `titulo` HISTÓRICO exato (com
  NBSP, hífen tipográfico `–`, símbolo `°`), não o OCR limpo. Isso
  evita aparecer 2 títulos "iguais mas diferentes" no GUI do
  supervisor.
- Quando não há histórico do MESMO promotor naquele PDV, pegar
  título de qualquer visita do PDV (de outro promotor) como fonte.

Combina com [[no-speculation-fixes]] e [[nao-deduzir-campos-de-dominio]]
— a fonte canônica é a tabela, não a dedução por concatenação.
