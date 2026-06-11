# Contexto do projeto — WizMart Qualidade App

## Regras de trabalho (definidas pelo Alan)

1. **Comunicação:** explicar sempre de forma objetiva, sem jargão técnico, em português claro.
2. **Alterações no código:** toda mudança deve ser baseada em **fatos verificados no código atual** — nunca em suposições ou no histórico da conversa. Se faltar informação para avançar com segurança, **perguntar antes** em vez de presumir.
3. **Alterações em geral (código, issues, dados):** perguntar antes de executar.
4. **Branch:** trabalhar direto na `main`. Não criar ramificações.
5. **Toda proposta deve explicitar os RISCOS da implantação** (definido pelo
   Alan em 11/06/2026). Considerar sempre que: há **muitos promotores usando
   o app ao mesmo tempo, em versões distintas**; eles **não podem perder o
   histórico de outros dias que ainda não sincronizou** e, principalmente,
   **não podem perder o trabalho atual**. Mudanças na área de id temporário/
   consolidação já causaram transtornos antes — tratar como alto risco.
6. **Pode-se apagar as informações internas do app, mas NUNCA as fotos
   processadas (com marca d'água) da galeria de fotos do celular do
   promotor** (definido pelo Alan em 11/06/2026). A galeria é o backup do
   promotor. Fato verificado no código: o app só ADICIONA à galeria
   (`Gal.putImage`, `watermark_queue.dart:278`) e não possui nenhuma
   chamada capaz de apagar da galeria — qualquer limpeza deve se restringir
   ao banco local (`pending_photos`) e aos arquivos internos do app
   (`wizmart_fotos/`).
7. **Antes de qualquer alteração proposta, ler e estudar 100% do código**
   (definido pelo Alan em 11/06/2026) — entender o fluxo inteiro afetado,
   para que a mudança não gere conflitos/problemas para os usuários
   (promotores em campo). Para não reestudar tudo a cada vez, existe o
   **mapa técnico granular `docs/fluxo-e-gatilhos-app.md`** (fluxos,
   gatilhos, máquinas de estado, com referência arquivo:linha): consultar
   o mapa + reler os arquivos afetados pela mudança. **Obrigatório manter
   o mapa atualizado em todo commit que altere comportamento descrito
   nele** — mapa desatualizado é pior que nenhum mapa.

## Fatos do domínio (definidos pelo Alan em 11/06/2026)

- **A marca d'água nas fotos do bucket é a informação mais correta/segura
  que temos sobre os fatos.** Para tirar dúvidas sobre uma visita, ler a
  imagem (OCR da marca d'água).
- **Antes de qualquer alteração**, verificar como o app captura e salva os
  dados de visitas realizadas e em andamento (qual edge function é usada e
  qual flag de status) — **não deduzir nada, buscar fatos** no código e no
  Supabase. Ler a tabela `status_visita`.
- A visita não realizada (**falta**) é carimbada **pelo Supabase** (não pelo
  app). **Detalhe do mecanismo (Alan, 11/06/2026): não há gatilhos/triggers
  de status no servidor — existe apenas um job NOTURNO que lê as visitas de
  D-1 (véspera) e: (a) marca Incompleta (5) se faltar URL de foto em um dos
  campos antes/depois; (b) marca como falta (3, Não Realizada) as agendadas
  não realizadas.** Consequência: o job NÃO re-avalia datas antigas — visita
  de dias anteriores alterada hoje não recebe carimbo retroativo; qualquer
  correção de status em data passada precisa setar o status explicitamente.
- O status **"em andamento" só existe na data de hoje**.
- O status **"incompleto" só existe em visitas anteriores** (datas passadas)
  que não têm URL/foto do "antes" ou do "depois".

### Fatos verificados em 11/06/2026 (tabela `status_visita` + código)

- Tabela `status_visita` no Supabase: **1=Concluída, 2=Em Andamento,
  3=Não Realizada, 4=Agendada, 5=Incompleta**.
- ⚠️ O código do app chama o status 5 de "Falta" (`statusFalta`), mas no
  servidor **5 = Incompleta** e **3 = Não Realizada**. Comentários do código
  (ex.: `sync_engine.dart`, cabeçalho de `faltas_screen.dart`) repetem o
  rótulo errado — o código em si está coerente com o servidor:
  `faltas_screen` busca `status_visita=3` (Não Realizada) e
  `realizado_screen` busca `status_visita` 1 ou 5 (Concluída + Incompleta).
- O app só ESCREVE status no servidor em 2 pontos (`visita_screen.dart`):
  ao abrir a visita envia **2 (Em Andamento)** e ao finalizar envia
  **Realizada** (local 3 → servidor 1, via `_toServerStatus`). O app nunca
  grava 3 (Não Realizada) nem 4 — esses são carimbados pelo Supabase.
- Edge function usada pelo app: **`gerar_datas_gabaritos_att`** (gera a
  programação do dia a partir dos gabaritos; chamada no pull do
  `sync_engine.dart` e na `programado_screen.dart`). A lógica que carimba
  Não Realizada/Incompleta é do lado do Supabase (não visível no app).
- Validado nos dados em 11/06: nenhuma visita "Em Andamento" em datas
  passadas; visitas "Incompleta" (263 desde 01/06) em geral sem nenhuma
  URL no slot antes e/ou depois.

### Anomalia temporal (termo definido pelo Alan em 11/06/2026)

- **"Anomalia temporal"** = divergência de datas em uma visita. Em cada
  visita, os campos `dia_hora_agendado`, `dia_hora_realizado`,
  `dia_hora_abertura`, `dia_hora_fotos_antes` e `dia_hora_fotos_depois`
  **e a data lida na marca d'água das fotos do bucket (OCR) devem se
  referir ao MESMO dia**. Qualquer divergência é anomalia temporal.
  (Existem outros tipos de anomalia; este termo cobre só divergência de
  datas.)
- Antes de limpar as URLs duplicadas dos arrays, conferir as fotos com
  marca d'água desde 01/06 contra essa regra.

## ⏳ Retomada de trabalho em andamento

Há uma investigação em aberto com pendências. **Leia
`docs/contexto-handoff-2026-06-11.md`** antes de qualquer tarefa — ele contém
o histórico completo da sessão anterior (estudo do código, issues encerradas,
caso Jessica, pendências no Supabase). Quando as pendências forem concluídas,
aquele arquivo temporário pode ser removido (perguntar ao Alan antes).
