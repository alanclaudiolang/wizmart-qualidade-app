# Contexto do projeto — WizMart Qualidade App

## ⭐ Regra principal: NÃO SUPOR NADA (definida pelo Alan em 11/06/2026)

Toda afirmação deve se basear em **fatos verificados** — no código, nos
dados, em testes executados nesta sessão ou em pesquisa — nunca em memória
de sessões anteriores, histórico da conversa ou dedução. **Se dá para
testar/verificar, testar ANTES de afirmar.** Vale para TUDO: respostas,
diagnósticos, configurações de ambiente, propostas — não só para mudanças
de código. (Exemplo real que motivou a regra: afirmar que a política de
rede estava restrita com base em anotação antiga, quando um teste de 2
segundos mostrava que já era acesso total.)

### 🚦 GATILHO DE PARADA (definido pelo Alan em 13/06/2026)
Pedir desculpas NÃO evita repetir o erro — este gatilho sim. Antes de
ESCREVER qualquer uma destas frases (ou equivalentes), PARAR e fazer as
2 verificações abaixo. As frases são o alarme:
- "é chute" / "seria chute" / "sem chute não dá"
- "não temos como" / "impossível" / "não dá para recuperar" / "fora do
  meu alcance" / "perda irreversível"
- "o promotor refez" / "nada aconteceu" / "nada se perdeu" / "já está
  resolvido" / "foi só rede"

Antes de afirmar qualquer uma delas, OBRIGATÓRIO:
1. **Buscar procedimento no contexto** — `grep` em `docs/` (logs,
   `memoria-codespace/`, `feedback_*`) e no CLAUDE.md. O projeto tem MUITO
   procedimento já escrito; presumir que não existe é o erro. (Ex.:
   preencher `dia_hora_abertura` = 1ª foto −30s estava em
   `feedback_recuperacao_manual_procedimento.md` — eu disse "é chute".)
2. **Investigar até o fim** — log completo (partes 2/3), bucket, marca
   d'água (OCR). O estado final pode esconder o bug/a perda. (Ex.: "Felipe
   refez, nada perdido" — ele NÃO tinha como refazer o "antes"; as fotos
   reais só existiam na galeria dele.)
Só afirmar a limitação DEPOIS de esgotar 1 e 2. Se mesmo assim for
limitação real, dizer o que foi verificado para chegar nela.


## Regras de trabalho (definidas pelo Alan)

1. **Comunicação:** explicar sempre de forma objetiva, sem jargão técnico, em português claro.
2. **Alterações no código:** toda mudança deve ser baseada em **fatos verificados no código atual** — nunca em suposições ou no histórico da conversa. Se faltar informação para avançar com segurança, **perguntar antes** em vez de presumir.
3. **Alterações em geral (código, issues, dados):** perguntar antes de executar.
   **3a. PUBLICAR exige pergunta SEMPRE (definido pelo Alan em 12/06/2026):**
   nenhum push que gere build/release (main ou dev) sem OK explícito do
   Alan NAQUELE momento — aprovação anterior não se estende ao próximo
   push, mesmo que pareça continuação do mesmo trabalho.
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
   **7a. LER 100% DOS ARQUIVOS antes de QUALQUER proposta de alteração do
   app (definido pelo Alan em 13/06/2026):** o mapa técnico é um índice,
   NÃO substitui a leitura. Antes de propor qualquer mudança no app, ler
   integralmente todos os arquivos `.dart` do projeto (não só os
   "afetados") — o objetivo é ter 100% do código na memória para que a
   correção de cada causa-raiz não gere outro bug por cegueira/falta de
   profundidade. Pode levar o tempo que precisar, inclusive em background.
   Motivo (Alan): "não existe um profissional extra que revise o que você
   faz — você tem que garantir sozinho que a solução não gera regressão".
   Registrar a cobertura da leitura (o que foi lido, o que faltou e por
   quê), como em `docs/analise-arquitetural-2026-06-13.md`.

8. **PROIBIDO diagnóstico raso de caso de campo (definido pelo Alan em
   13/06/2026).** Ao investigar um issue/relato de promotor, NUNCA concluir
   "nada aconteceu / foi só rede" a partir do estado FINAL. O estado final
   pode estar correto **por sorte de timing ou porque o promotor refez** —
   e isso ESCONDE o bug. Checklist obrigatório, com o tempo e a
   profundidade que precisar (inclusive em background):
   1. **Reconstruir a cronologia COMPLETA do log**, do início ao fim (não
      só as últimas linhas) — ler as partes 2/3 dos comentários do issue,
      que trazem as linhas mais recentes.
   2. **Cruzar os 5 campos de data da visita** (`dia_hora_abertura`,
      `dia_hora_fotos_antes`, `dia_hora_fotos_depois`, `dia_hora_realizado`
      + data da marca d'água) contra a ordem física esperada
      (abertura ≤ fotos_antes ≤ fotos_depois ≤ realizado). **Qualquer
      inversão é "anomalia temporal" e PROVA reinício/zeramento**, mesmo
      que o resultado final pareça completo. (Caso real que motivou a
      regra: Felipe #2441 — `abertura`=13:11 POSTERIOR a `fotos_antes`=12:49
      provou que a visita foi rebaixada e reiniciada; eu havia concluído
      "nada aconteceu" olhando só o 7/7 final — diagnóstico raso e ERRADO.)
   3. **O relato do promotor é FATO de campo.** Se o log/servidor parecem
      contradizê-lo, a falha está na MINHA leitura — investigar mais fundo
      até reconciliar, nunca descartar o relato como "percepção".
   4. Confirmada a perda/zeramento por timing, perguntar: "e se a rede
      fosse pior?" — se a resposta é "perda real", é bug grave, não
      "rede ruim".

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

## Ambiente de execução (fatos verificados em 11/06/2026)

- **Política de rede: ACESSO TOTAL.** Verificado por teste em 11/06/2026
  (curl para domínios diversos respondeu). Esta informação **prevalece**
  sobre o que `docs/contexto-handoff-2026-06-11.md` diz sobre rede — lá
  está retratada a situação antiga (acesso restrito por domínio), que o
  Alan depois mudou para acesso total.
- Credenciais externas (token do Codemagic, chave da App Store Connect)
  ainda **não cadastradas** — verificado: nenhuma variável de ambiente
  com esses nomes existe. Quando o Alan cadastrar, entram como variáveis
  de ambiente do ambiente "Default" e só aparecem em **sessões novas**.
- **Publicação iOS**: contexto completo e status em
  **`docs/publicacao-ios.md`** (consolidado em 11/06 das memórias do
  Codespace + histórico). Resumo: app submetido à App Store em 01/06 com
  pedido de distribuição Unlisted; 3 rejeições corrigidas até 04/06;
  parado aguardando resposta do ticket Unlisted; quando aprovado, gerar
  build novo e resubmeter. O `codemagic.yaml` configura trigger por push,
  mas **na prática o webhook não dispara** (fato registrado na memória do
  Codespace) — builds saem manualmente ou via API. `submit_to_testflight:
  false`. App Apple ID 6774250898, bundle `com.wizmart.promotor`.
- **O repositório GitHub é PÚBLICO** (verificado em 11/06 por acesso
  anônimo + API). Motivo provável: o auto-update do APK exige URL pública
  e o GitHub não permite release pública em repo privado. NUNCA commitar
  credenciais. Exposições conhecidas a tratar no futuro (sem quebrar o
  auto-update dos promotores): issues com dados de produção e anon key
  do Supabase no código.
- **Regra definida pelo Alan (11/06/2026) para a publicação iOS** — o
  comportamento atual acima está ERRADO e deve ser corrigido no
  `codemagic.yaml`: a publicação iOS deve acontecer **somente mediante
  solicitação do Alan** (nunca automática a cada push); quando ele
  solicitar **testar na `dev`**, o build da `dev` deve ir para o
  **TestFlight**. Pré-requisitos antes de mexer no `codemagic.yaml`:
  credenciais cadastradas (acima) e verificação do histórico de builds
  no Codemagic (nunca confirmamos se algum build iOS passou desde 28/05).

## ⏳ Retomada de trabalho em andamento

**Leia `docs/pendencias-2026-06-12.md`** — checklist atualizado (build 245
em campo, limpeza D-1, verificações do job noturno e casos em aberto).
Histórico completo das correções de 11/06 em
`docs/log-correcoes-anomalias-2026-06-11.md`. O handoff antigo
(`docs/contexto-handoff-2026-06-11.md`) está concluído — pode ser removido
(perguntar ao Alan antes).
