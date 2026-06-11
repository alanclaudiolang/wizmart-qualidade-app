---
name: no-force-update-em-mudanca-estrutural
description: "NUNCA ativar [FORCE-UPDATE] em build que altera estrutura (idTemp, schema, formato de path, fórmula de hash). Sempre considerar promotores offline com pendências."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5b3db7e3-0a85-41f4-a33b-0441e2dfb1ba
---

**REGRA HARD:** quando o fix altera **estrutura** — fórmula de
`idTemp`, schema do Drift, formato de path no Storage, hash de chave
natural, formato do `pending_photos`/`outbox_items`, etc — **NÃO
ativar `[FORCE-UPDATE]`**, NUNCA. Mesmo que a maioria dos promotores
esteja online e sem pendências.

**Why:**
- O bloqueio de update por pendências (proteção no código) impede
  promotores com `pending_photos`/`outbox` travados de atualizar
  normalmente.
- A única saída deles vira **reinstalar** o app (uninstall + install).
- Reinstalação **apaga o SQLite local** → todas as visitas finalizadas
  offline + fotos só locais somem definitivamente.
- Em 2026-05-29 ativei force-update do build 182 (idTemp determinístico
  SHA-1) sem considerar isso. O Gabriel/335 estava offline com 7
  visitas finalizadas + 154 pendências. Reinstalou pra atualizar. **As
  7 visitas + fotos locais foram perdidas pra sempre** (bucket dele de
  29/05 vazio — nada tinha subido).

**How to apply:**
- Antes de oferecer `[FORCE-UPDATE]`: classificar o commit. Se mudou
  estrutura (idTemp, schema, hash, formato de path) → **NÃO sugerir
  force-update**. Comunicar isso explicitamente ao usuário.
- Force-update só pra fixes de UI / lógica que não criem
  incompatibilidade entre dados antigos e novos.
- Quando dúvida → optar pelo update normal (badge "atualizar"), que
  respeita o bloqueio por pendências e o promotor escolhe o momento
  com rede boa (pendências sincronizam, depois atualiza sem perder).
- Vale pra qualquer mudança em: `_pullVisitasDia` (idTemp),
  `_processPhotoUpload` (visitaHash), `consolidarVisitaNoServer`,
  `deleteVisitasSincronizadasSemPendencias`, schema do Drift,
  formatos de `payload` para o Supabase.

Combina com [[no-speculation-fixes]] e [[investigar-issues-a-fundo]]:
investigar a fundo e agir com evidência, mas também antecipar o efeito
em campo de quem está offline com trabalho preso.
