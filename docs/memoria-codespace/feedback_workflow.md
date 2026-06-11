---
name: Build e push automáticos sem perguntar
description: Em fase de desenvolvimento - aja direto, sem confirmar commits/push/build/comandos rotineiros
type: feedback
originSessionId: 5b3db7e3-0a85-41f4-a33b-0441e2dfb1ba
---
Usuário autoriza globalmente comandos rotineiros neste projeto. Não pergunte "posso commitar/dar push/rodar X/instalar Y?" — apenas faça. Inclui também leituras inofensivas (`gh issue list`, `ls`, `cat` via Read tool, etc).

**Why:** O projeto WizMart está em fase ativa de desenvolvimento. O usuário (alanclaudiolang) testa rapidamente cada iteração baixando o APK pela release `v-latest`. Pedir confirmação pra cada ação interrompe o ciclo. Usuário disse explicitamente: "sempre gere o build, estamos na fase de desenvolvimento, não precisa fazer tantas perguntas" e depois "autorizo todos os comandos pare de ficar me perguntando o que deve executar".

**How to apply:**
- Após editar arquivos, rode `flutter analyze` nos arquivos tocados
- Comite com mensagem clara
- `git push origin dev` direto; `git push origin main` direto quando o usuário pede produção
- Monitore o build em background com `gh run watch ... --exit-status`
- Leituras de issues/PRs/CI (`gh issue list`, `gh run list`, etc) — apenas execute
- Quando uma denied tool exigir comando alternativo trivial, execute sem confirmar
- Só interrompa pra perguntar se houver decisão real de produto/arquitetura (ex: qual abordagem técnica escolher) — não pra confirmar ações rotineiras
- Não use AskUserQuestion pra "posso commitar/dar push/agrupar/mudar branch/listar issues" — apenas faça
