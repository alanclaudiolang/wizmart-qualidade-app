# Publicação na Play Store — Promotor Wizmart

Decisão do Alan em 27/07/2026 (revertendo o descarte de 15/07): distribuir
pela Play Store. Motivo: Google Play Protect passou a BLOQUEAR a
instalação do APK avulso ("nunca viu um app desse desenvolvedor") —
fricção para ~70 promotores. Conta: organização **Smart Café**
(ID 7062012092761442057) — conta de organização NÃO tem exigência de
teste fechado de 14 dias.

## Decisão técnica: mesma chave de assinatura

No Play App Signing, usar a NOSSA chave (`wizmart-upload-2026.jks`,
fingerprint `09b18e7a...`) como chave de assinatura do app — exportada
via PEPK. Consequência: quem instalou 263/264/265 pelo link ATUALIZA POR
CIMA para a versão da loja, sem desinstalar. Se deixássemos o Google
gerar outra chave, a frota nova teria que desinstalar de novo.

## O que já está pronto

- **AAB**: o pipeline `build-apk-android` gera e publica o artefato `aab`
  a cada run (com `--build-number` = BUILD_NUMBER como versionCode, que a
  Play exige crescente a cada envio).
- **Política de privacidade** (obrigatória), hospedada:
  `https://czvrbntewaisegvjdzyj.supabase.co/storage/v1/object/public/Arquivos/site/politica-privacidade.txt`
- **Ícone 512×512 e banner 1024×500**: entregues ao Alan na conversa de
  27/07 (regenerar se a arte original em alta aparecer).
- **Textos da ficha** (abaixo).

## Textos da ficha (copiar/colar)

**Nome do app (máx. 30):** `Promotor Wizmart`

**Descrição curta (máx. 80):**
`Registro de visitas e reposição em pontos de venda para promotores WizMart.`

**Descrição completa:**
```
O Promotor Wizmart é o aplicativo de trabalho dos promotores e
promotoras da WizMart (Smart Café) para registro de visitas de
reposição em pontos de venda.

Recursos:
• Agenda do dia com os PDVs a visitar
• Registro fotográfico "antes e depois" da reposição, com marca d'água
  automática (PDV, promotor, data e hora)
• Funciona offline: fotos e registros são guardados no aparelho e
  enviados automaticamente quando a internet volta
• Checklist de finalização da visita
• Histórico de visitas realizadas

Aplicativo de uso restrito: requer login fornecido pela equipe WizMart.
```

**Categoria:** Corporativo (Business). **E-mail de contato:**
plataformawizmart@gmail.com. **Site:** https://qualidade.wizmart.com.br

## Formulários do Console (respostas)

**Segurança dos dados (Data safety):**
- Coleta dados? SIM. Criptografia em trânsito? SIM. Exclusão sob
  solicitação? SIM (via contato).
- Localização (aproximada+precisa): coletada, finalidade "Funcionalidade
  do app", não compartilhada.
- Fotos: coletadas, "Funcionalidade do app", não compartilhadas.
- Infos pessoais (nome, e-mail): coletadas, "Funcionalidade do app /
  Gerenciamento da conta", não compartilhadas.
- IDs do dispositivo: NÃO coletados (device_info guarda modelo/versões,
  não identificadores de publicidade).

**Classificação de conteúdo:** categoria "Utilitário/Produtividade",
todas as respostas "não" (sem violência, apostas, etc.).

**Público-alvo:** 18+. **Anúncios:** não contém.

**Acesso ao app (App access)**: o app exige login → OBRIGATÓRIO fornecer
credencial de teste para o revisor do Google (criar um usuário promotor
de teste no Supabase; NÃO usar conta de promotor real).

## Checklist no Console (ações do Alan, na ordem)

1. **Criar app**: Página inicial → "Criar app" → nome `Promotor Wizmart`,
   idioma pt-BR, tipo App, gratuito.
2. **Play App Signing / chave**: em Versão → Configuração → Integridade
   do app → escolher **"Usar a mesma chave de assinatura"** → opção
   **"Exportar e fazer upload de uma chave de um Java Keystore"** → o
   console mostra uma **chave de criptografia (hex longo)** → enviar esse
   hex ao Claude, que adiciona o passo PEPK no pipeline e devolve o
   `output.zip` para upload.
3. **Testes internos**: Versão → Teste interno → criar versão → enviar o
   **AAB** (artefato `aab` do pipeline, entregue pelo Claude) → adicionar
   os e-mails de teste (Alan + 1-2 pessoas) → distribuir e validar.
4. **Ficha da loja**: colar textos acima + ícone + banner + **2 a 8
   capturas de tela** (tirar do celular: home com agenda, tela de fotos).
5. **Formulários**: Segurança de dados, Classificação, Público-alvo, App
   access (credencial de teste) — respostas acima.
6. **Produção**: promover a versão do teste interno → produção → enviar
   para revisão (1-7 dias).

## Depois da aprovação

- Botão do site (FlutterFlow) → trocar Launch URL para o link da loja
  `https://play.google.com/store/apps/details?id=com.wizmart.wizmart_app`.
- Auto-update: a Play assume as atualizações de quem instalou pela loja.
  O latest.json continua servindo a frota que instalou pelo link (as duas
  rotas convivem; migrar o version_check para abrir a loja é build
  futuro).
- Automação (opcional): criar service account (API do Play) e cadastrar
  como variável p/ o pipeline publicar AAB direto na faixa de testes.
