# Firebase

Projeto: `agenda-pastoral-15bff` (plano gratuito Spark).

## Projeto configurado

O app web já está ligado ao projeto **`agenda-pastoral-15bff`**
(`lib/firebase_options.dart` e `.firebaserc`). No console do Firebase, confira se:

- **Authentication → Método de login → E-mail/senha** está ativado;
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

## Definir quem é o pastor

1. Abra o site, crie a conta do pastor com e-mail e senha e preencha o cadastro.
2. No console: **Firestore → users → (documento do pastor)**, mude o campo `role` de
   `member` para `pastor`.

Por segurança, ninguém consegue se promover a pastor pelo próprio app.

## Para os membros

Mande o link do site. No celular, o membro abre e usa **"Adicionar à tela inicial"**,
e o app passa a funcionar como um aplicativo instalado. Publicar na Google Play
(US$ 25, pagamento único) ou na App Store (US$ 99 por ano) é opcional.

## Testar sem criar projeto (emuladores locais)

```bash
firebase emulators:start                                   # Auth + Firestore + painel em localhost:4000
flutter run -d chrome --dart-define=EMULATORS=true
# Emulador Android: acrescente --dart-define=EMULATOR_HOST=10.0.2.2
```

Para virar pastor no emulador, mude o `role` no painel em <http://localhost:4000/firestore>.

## Como os dados ficam guardados

| Coleção | Conteúdo | Quem lê |
|---|---|---|
| `users/{uid}` | nome, telefone, endereço, bairro, coordenadas, `role` | o próprio membro e o pastor |
| `availability/{id}` | janelas de atendimento (`start`, `end`) | todos os logados |
| `visits/{id}` | visita completa, com nome, telefone e local | o próprio membro e o pastor |
| `agenda/{aaaa-mm-dd}` | ocupação do dia: horário, bairro e coordenada arredondada (~1 km) | todos os logados |
| `notifications/{id}` | avisos de nova visita e de cancelamento | só o pastor |

**Privacidade:** para calcular se o pastor chega a tempo, o app do membro precisa saber
onde fica a visita anterior e a seguinte. Ele lê isso de `agenda/`, que não tem nome,
telefone nem endereço: só o bairro e uma coordenada arredondada.

**Reserva sem conflito:** a reserva é uma transação que lê `agenda/{dia}`, refaz o
cálculo de deslocamento e grava a visita. Se dois membros tentarem o mesmo horário ao
mesmo tempo, só um consegue; o outro recebe o motivo.

**Limite conhecido:** como `agenda/` é gravado pelo próprio app do membro, as regras
só permitem acrescentar ou remover um horário por vez. Um membro mal-intencionado
ainda conseguiria apagar o horário de outro. Para fechar isso, a reserva pode virar
uma Cloud Function (ver abaixo).

## Custos

| Peça | Custo |
|---|---|
| Authentication por e-mail/senha | Grátis |
| Firestore | Grátis até 50 mil leituras e 20 mil gravações por dia |
| Hosting | Grátis até 10 GB armazenados e 360 MB/dia de tráfego |
| Geocodificação do endereço (Nominatim/OpenStreetMap) | Grátis, 1 consulta por segundo |
| Cálculo de deslocamento | Grátis (estimativa feita no próprio app) |

**Próximo passo opcional:** notificação *push* no celular do pastor com o app fechado.
Exige Cloud Functions, que só rodam no plano **Blaze**. O Blaze pede cartão, mas tem
cota grátis de 2 milhões de execuções por mês, o que dá R$ 0 nesse volume. Configure um
alerta de orçamento. Sem isso, o pastor vê as visitas novas em tempo real sempre que
abre o app (sino com contador).
