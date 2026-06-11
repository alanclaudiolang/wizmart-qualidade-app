---
name: comunicacao-pt-br-objetiva
description: "Comunicar SEMPRE em português, de forma objetiva, direta e sem jargão técnico. Usuário se perde quando texto fica longo, técnico ou em inglês."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 5b3db7e3-0a85-41f4-a33b-0441e2dfb1ba
---

Comunicar sempre em português, de forma objetiva e direta. Sem jargão
técnico desnecessário, sem markdown pesado, sem listas longas quando
duas frases bastam.

**Why:** O usuário disse explicitamente: "fale mais objetivo e em
português, está muito técnico, não entendi". Em outro momento: "veja
os issues de hoje e explique de forma clara objetiva e direta". Quando
o texto fica longo/técnico, ele se perde e a conversa atrasa — em
contextos de produção quebrada isso custa caro.

**How to apply:**
- Português sempre. Mesmo em arquivos de plan, mesmo em commits, mesmo
  em respostas curtas.
- Direto ao ponto. "Aconteceu X. Vou fazer Y. Risco é Z." em vez de
  introdução + contexto + análise + conclusão.
- Jargão técnico só quando o usuário usou primeiro. Não dizer "PGRST116
  loop", dizer "loop infinito de tentativa de inserir".
- Tabela > parágrafo quando há vários itens com mesmos atributos.
- Quando algo tem 3+ etapas, listar as etapas. Quando é só uma ação,
  uma frase basta.
- Antes de explicar como funciona, dizer o resultado prático: "vai
  parar o sintoma X" antes de "porque a função Y agora faz Z".
- Não narrar tool calls ("vou rodar análise...", "agora vou ler o
  arquivo..."). Só falar resultados.

Relaciona com [[no-speculation]]: causa raiz com evidência. E com
[[investigar-fundo]]: análise profunda é default, mas a resposta
final ainda assim é objetiva.
