# Firebase

Projeto: `agenda-pastoral-15bff` (plano gratuito Spark).

## Projeto configurado

O app web já está ligado ao projeto **`agenda-pastoral-15bff`**
(`lib/firebase_options.dart` e `.firebaserc`). No console do Firebase, confira se:

- **Authentication → Método de login → E-mail/senha** está ativado (e **Google**, se quiser o
  botão “Continuar com Google”; em *Configurações → Domínios autorizados*, inclua
  `agenda-pastoral-15bff.web.app`);
- **Firestore Database** foi criado (de preferência em `southamerica-east1`, São Paulo).

Android e iOS continuam no modo demonstração até alguém rodar `flutterfire configure`
(precisa de Flutter e `firebase login` no computador). Ele substitui
`lib/firebase_options.dart` mantendo a configuração web.

## Publicação automática pelo GitHub

A cada push no `main` com os testes verdes, a CI publica as regras do Firestore e o site.
Para isso ela precisa de uma chave do projeto (uma vez só):

1. Console do Firebase → engrenagem → **Configurações do projeto → Contas de serviço**
   → **Gerar nova chave privada**. Vai baixar um arquivo `.json`.
2. GitHub → repositório → **Settings → Secrets and variables → Actions → New repository secret**:
   - Name: `FIREBASE_SERVICE_ACCOUNT`
   - Secret: cole o conteúdo inteiro do arquivo `.json`
3. Apague o arquivo `.json` do computador. **Nunca** coloque essa chave no código nem em
   mensagens: ela dá acesso total ao projeto.
4. Em **Actions**, rode de novo o último workflow (Re-run all jobs).

O site fica em <https://agenda-pastoral-15bff.web.app>.

Sem a chave, a etapa "Publicar no Firebase" é pulada e o resto da CI continua normal.
Alternativa manual, no computador: `npm install -g firebase-tools`, `firebase login`
e `firebase deploy` na pasta do projeto.

## Primeiro acesso

1. Publique (CI no `main` ou `firebase deploy`) para subir as regras novas.
2. **Entre primeiro com a conta que vai administrar.**
   - Projeto novo: a primeira conta criada vira *Secretaria / administração*.
   - Este projeto já tinha um pastor da versão anterior: ao entrar, ele marca o projeto como
     iniciado. Mude o `role` dele para `admin` (ou mantenha `pastor`) em
     **Firestore → users → (documento)**. Contas antigas com `role: member` aparecem como
     “aguardando aprovação” até alguém liberar em **Mais → Usuários e permissões**.
3. Em **Mais → Dados da igreja**, preencha endereço, telefone da secretaria, canal do YouTube e PIX.
4. Em **Agenda → Programação**, cadastre os cultos e atividades semanais (a escala diaconal usa
   os cultos daqui).
5. Em **Pessoas**, cadastre os membros (ou deixe cada um preencher “Meu cadastro” e confira).
   Marque o **ofício** de pastores, presbíteros e diáconos: eles aparecem em Contatos.
6. Aprove as contas em **Mais → Usuários e permissões**, escolha o perfil e **vincule ao cadastro**
   da pessoa (libera visita pastoral, “Meu cadastro” e “Minha escala”).

## Como os dados ficam guardados

| Coleção | Conteúdo | Quem lê |
|---|---|---|
| `users/{uid}` | nome, e-mail, perfil, cadastro vinculado, datas em que não pode servir | a própria pessoa, secretaria, pastor e coordenação da escala |
| `members/{id}` | rol: situação, ofício, contato, endereço, datas, ministérios | secretaria, pastor e conselho; todos veem só quem tem ofício; cada um vê o seu |
| `pastoralNotes/{memberId}` | anotações pastorais | pastor e secretaria |
| `availability/{id}` | horários liberados pelo pastor | todos |
| `visits/{id}` | visita completa (nome, telefone, endereço, motivo) | pastor e quem marcou |
| `agenda/{aaaa-mm-dd}` | ocupação do dia: horário, bairro e coordenada arredondada | todos |
| `notifications/{id}` | avisos para o pastor | pastor e secretaria |
| `weekly/{id}` | programação semanal | todos |
| `events/{id}` (+ `registrations`, `tasks`, `budget`) | eventos, inscrições, tarefas e orçamento | publicados: todos; rascunhos, tarefas e orçamento: liderança |
| `diaconia/{id}` | escala por culto, nomes e confirmações | publicadas: todos; rascunhos: coordenação |
| `videos`, `avisos` | vídeos do YouTube e mural | todos |
| `oracao/{id}` | pedidos de oração | públicos: todos; reservados: conselho e autor |
| `config/igreja`, `config/agenda` | dados da igreja e ajustes das visitas | todos |

**Reserva sem conflito:** marcar visita é uma transação que relê `agenda/{dia}`, refaz o cálculo
de deslocamento e grava a visita. Se dois membros tentarem o mesmo horário, só um consegue; o
outro recebe o motivo.

**Limite conhecido:** como `agenda/` é gravado pelo próprio app do membro, as regras só permitem
acrescentar ou remover um horário por vez. Um membro mal-intencionado ainda conseguiria apagar
o horário de outro. Para fechar isso, a reserva pode virar uma Cloud Function (plano Blaze).

## Custos

| Peça | Custo |
|---|---|
| Authentication (e-mail/senha e Google) | Grátis |
| Firestore | Grátis até 50 mil leituras e 20 mil gravações por dia (cache offline reduz leituras) |
| Hosting | Grátis até 10 GB armazenados e 360 MB/dia de tráfego |
| Endereço → coordenadas (Nominatim/OpenStreetMap) | Grátis, 1 consulta por segundo, só ao salvar cadastro |
| Deslocamento das visitas | Grátis (calculado no aparelho) |
| Vídeos | Grátis (player do YouTube; título pelo oEmbed público) |

**Próximo passo opcional:** notificações *push* (visita nova para o pastor, lembrete de escala
para os diáconos) exigem Cloud Functions no plano **Blaze**, como no app dos Cânticos. Sem isso,
os avisos aparecem no sino do pastor sempre que ele abre o app.
