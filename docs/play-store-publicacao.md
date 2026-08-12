# Publicação na Play Store — Promotor Wizmart

## 🔁 12/08/2026 — versão 1.0.3 (build 271) gerada p/ atualização

AAB em `Arquivos/versoes-apk/promotor-wizmart-v1.0.3-build271.aab`
(sha256 f8fb828a...). Upload no Console feito pelo Alan (Produção →
Nova versão). Conteúdo: tela Pendente, correções caso Caline, msg de
senha. versionCode 271 > 269 em produção.

## ✅ APROVADO E PUBLICADO EM 09/08/2026

Página no ar (verificado 11/08 por acesso público):
https://play.google.com/store/apps/details?id=com.wizmart.wizmart_app
Após a rejeição de 04/08 (credenciais — ver abaixo), o reenvio de 05/08
com a conta demo alan.lang+promotor_rj passou. **NÃO apagar essa conta:
é a credencial de revisão registrada no Console (necessária em toda
atualização futura).** A conta revisor.google.teste@wizmart.com.br pode
ser apagada.

**Migração da frota (fato verificado 11/08):** o APK 262 de campo é
assinado com a CHAVE ANTIGA (sha256 do cert `581b017f...`, perdida na
suspensão do GitHub) — diferente da chave da loja. Logo 257/262 NÃO
atualizam por cima: o caminho é sincronizar 100% → desinstalar →
instalar da loja. Galeria (fotos com marca d'água) sobrevive à
desinstalação. Manter o canal Supabase (URL fixa/latest.json) até a
frota migrar.

## ❌→✅ REJEIÇÃO 04/08 CORRIGIDA em 05/08 — REENVIADO

Google rejeitou em 04/08: "As credenciais de login estão incorretas" —
o revisor não conseguia entrar. **Causa raiz (erro na criação da conta
de teste em 28/07):** a linha na tabela `users` ficou com `uid` NULL e
`tipo_user` NULL. A senha autenticava no Supabase Auth (o last_sign_in
do revisor em 05/08 00:11 UTC prova), mas o app busca o usuário por
`uid` (`auth_screen.dart:177` e `login_flow.dart:97`) e exige
`tipo_user=3` — resultado: "Usuário não encontrado no banco de dados"
e signOut. **Correção:** UPDATE na linha id=638 (`uid` = id do auth,
`tipo_user` = 3); login simulado de ponta a ponta (auth + consulta por
uid com token do usuário/RLS) → OK. Correção validada, mas o Alan
decidiu (05/08) trocar a credencial do revisor pela conta demo já
aprovada pela Apple: **alan.lang+promotor_rj@paggora.com.br /
1234567890** (users id 5, tipo_user 3, com gabaritos/rota — revisor vê
agenda real). Validada de ponta a ponta em 05/08. A conta
revisor.google.teste@wizmart.com.br também ficou funcional após o
conserto (pode ser apagada depois). Reenvio: atualizar "Acesso ao app"
(App access) com a credencial nova + botão "Enviar N mudanças para
revisão" na Visão geral da publicação.

## 🚀 STATUS: EM ANÁLISE NO GOOGLE (enviado em 28/07/2026)

App criado e ENVIADO PARA REVISÃO no Console (conta org Smart Café) em
28/07, pelo Alan com passo a passo do Claude. Estado:
- **Versão em produção: build 269 (1.0.2)** — o AAB definitivo:
  consulta a Play p/ update (in_app_update), SEM auto-instalação de APK
  (REQUEST_INSTALL_PACKAGES removida no 268) e SEM READ_MEDIA_IMAGES
  (removida no 269 — app só usa câmera; confirmado por leitura de 100%
  dos 44 .dart).
- Países: Brasil + Estados Unidos (EUA inofensivo; remover depois se
  quiser). Ficha completa (descrição, ícone, banner, 5 capturas fone +
  tablet 7"/10"). Formulários todos preenchidos (dados/classificação/
  público 18+/ID publicidade NÃO/financeiro NÃO/saúde NÃO).
- Conta de teste do revisor (criada no Supabase auth + users):
  revisor.google.teste@wizmart.com.br / RevoLHC0vFBcs#7 (apagar após
  estabilizar, se quiser).
- Página de exclusão de conta (exigência):
  https://czvrbntewaisegvjdzyj.supabase.co/storage/v1/object/public/Arquivos/site/exclusao-conta.txt
- Prazo de revisão: 1-7 dias → e-mail no plataformawizmart@gmail.com.

## QUANDO APROVAR (próxima sessão/rodada)
1. Botão do site (FlutterFlow → Launch URL) → página da loja:
   https://play.google.com/store/apps/details?id=com.wizmart.wizmart_app
2. Migração da frota 257/262: desinstalar com trabalho 100% sincronizado
   → instalar da loja (Claude redige a mensagem de WhatsApp).
3. Aposentar canal Supabase de APK (fixed URL/latest.json) quando a
   frota migrar; remover EUA dos países se o Alan quiser.
4. Se o revisor pedir ajuste: trazer o e-mail ao Claude.


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

## 🤖 ROTEIRO DA PRÓXIMA SESSÃO — publicação AUTOMATIZADA (28/07)

Decisão do Alan: ele NÃO fará ações manuais. Credenciais
`GOOGLE_PLAY_EMAIL`/`GOOGLE_PLAY_PASSWORD` salvas no ambiente Claude
(aparecem em sessão nova). A sessão nova deve:

1. Verificar `env | grep GOOGLE_PLAY` (existem? senão, avisar o Alan).
2. **Playwright + Chromium** (pré-instalado): login em
   https://play.google.com/console (conta org Smart Café, id
   7062012092761442057). ⚠️ o 2FA vai pedir aprovação no CELULAR do
   Alan — AVISÁ-LO no chat antes de disparar o login e aguardar.
   Google pode bloquear login automatizado → plano B: ditar cliques.
3. Criar app: nome `Promotor Wizmart`, pt-BR, App, gratuito.
4. Integridade do app → "Usar a mesma chave de assinatura" → "Exportar
   chave de um Java Keystore" → copiar a CHAVE DE CRIPTOGRAFIA (hex) →
   rodar PEPK. A keystore está no Secure Files (pipeline baixa; pepk.jar
   em https://www.gstatic.com/play-apps-publisher-rest/pepk.jar) — criar
   step temporário no pipeline que gera o output.zip como artefato, e
   subir no Console via navegador.
5. AAB: artefato `aab` do run 50+ (build 267 — o que consulta a Play
   direto). Subir em Teste interno primeiro.
6. Ficha: textos deste doc; ícone/banner:
   `{SUPABASE}/storage/v1/object/public/Arquivos/site/play-icone-512.png`
   e `.../play-banner-1024x500.png`. Capturas de tela: pedir ao Alan
   (mín. 2) se ainda não enviou.
7. Usuário de teste do revisor: criar via service_role
   (auth.admin.createUser + linha na tabela users) — e-mail fictício
   claramente de teste; anotar credencial no campo "App access".
8. Formulários (Data safety/classificação/público): respostas abaixo.
9. Enviar para produção; monitorar aprovação; quando aprovado: atualizar
   botão do site (FlutterFlow → Launch URL → página da loja) e orientar
   migração da frota 257/262 (desinstalar com trabalho sincronizado).

## Checklist no Console (referência manual — plano B)

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
