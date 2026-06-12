# Pendências para 12/06/2026 (gravadas em 11/06 à noite)

> Contexto do dia 11/06: ver `docs/log-correcoes-anomalias-2026-06-11.md`
> (todas as correções com backups), `docs/fluxo-e-gatilhos-app.md` (mapa
> técnico + changelog do build) e `docs/memoria-codespace/` (memórias).
> Build 245 publicado 11/06 ~19h (limpeza D-1 + 4 correções); promotores
> recebem no 1º acesso de 12/06 (D+1, sem force-update).
> A service key do Supabase está na variável de ambiente
> `SUPABASE_SERVICE_KEY` (sessões novas já nascem com ela).

1. **Logs da limpeza D-1**: ler linhas `limpeza-d1` nas issues automáticas
   que chegarem de celulares no build 245 — auditar o que foi apagado
   (deve ser só foto confirmada no servidor, de dias anteriores).
2. **Job noturno**: conferir se as avulsas de 11/06 não realizadas foram
   carimbadas (3). Se amanhecerem como 4 (Agendada), o filtro do job tem
   segunda lacuna — investigar critério no Supabase. (1ª lacuna já vista:
   pulou as 4 fantasmas do Thiago de 10/06; corrigidas manualmente.)
3. **Correções de 11/06 seguraram?** Reconferir duplicatas/arrays de
   Felipe (34), Thiago (115) e as 5 do Mauro (412) — celulares com build
   antigo podem ter regravado por cima.
4. **Caso Thamara (170)**: home vazia — confirmar que normalizou após
   atualizar pro 245 (guard da purga).
5. **OCR completo das 115 fotos trocadas** (Felipe/Thiago) — validação
   final pela marca d'água, conforme regra da memória (path é pré-filtro).
6. **Jeferson (590)**: visitas recuperadas entram na avaliação do
   supervisor (Leandro, 564) — conferir se issue #619 pode fechar (foto
   presa 12 dias; app dele voltou a funcionar e dados recuperados).
7. **Frente iOS**: crash "Null check" na home do build 19 do TestFlight
   (issue #642, teste do Alan em 11/06 — fechada, bug rastreado aqui).
   O build 19 é anterior às correções do Android 245; ao retomar a
   esteira iOS, gerar build novo a partir da main atual. O
   `CODEMAGIC_API_TOKEN` já está na variável de ambiente.
8. Decisões menores em aberto (sem pressa): aviso proativo de issues
   novas; anonimizar nomes de promotores nos docs (repo é PÚBLICO);
   modo de trabalho (docs direto × perguntar sempre); destino das 6
   visitas com anomalia temporal permanente.
