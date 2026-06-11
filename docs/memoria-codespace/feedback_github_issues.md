---
name: feedback-github-issues
description: "Sempre verificar e reportar proativamente issues abertas no repo do app (label \"auto-reportado\") no início de cada turno, mesmo sem o usuário perguntar."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5b3db7e3-0a85-41f4-a33b-0441e2dfb1ba
---

No início de QUALQUER interação aqui na conversa do projeto wizmart-qualidade-app, verificar se há issues abertas no GitHub e mencionar pro usuário se algum apareceu desde o último turno.

**Why:** O usuário pediu explicitamente: "em toda nossa interação aqui, me avise se existe algum issue novo não tratado, mesmo que eu não pergunte". O app tem auto-report quando dá erro em alguma tela (label `auto-reportado`), e o usuário quer ficar a par sem precisar consultar o GitHub o tempo todo.

**How to apply:**
- Rodar no início de cada turno: `gh issue list --repo alanclaudiolang/wizmart-qualidade-app --state=open --label=auto-reportado --limit=10 --json number,title,labels,createdAt`
- Se houver issues abertas, listar resumidamente no começo da resposta antes de continuar com o pedido do usuário.
- Se não houver, seguir direto sem ficar avisando "sem issues".
- Issues fechadas ou sem o label `auto-reportado` não precisam ser mencionadas (são manuais).
- Quando for inicializar o projeto, inclua essa checagem mesmo se a pergunta do usuário for sobre outra coisa — é proativo, não reativo.
