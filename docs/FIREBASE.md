# Firebase

O app já está pronto para o Firebase. Falta só criar o projeto (é grátis) e gerar o
arquivo de configuração. Enquanto o projeto não existe, o app abre no **modo demonstração**.

## 1. Criar o projeto (uma vez, uns 10 minutos)

1. Acesse <https://console.firebase.google.com> e clique em **Criar projeto**. Pode
   desativar o Google Analytics. O plano começa no **Spark (gratuito)**.
2. **Authentication → Começar → Método de login → E-mail/senha → Ativar.**
3. **Firestore Database → Criar banco de dados**:
   - local: `southamerica-east1 (São Paulo)`
   - modo: **produção** (as regras do repositório liberam só o necessário)
4. No computador, com Flutter e Node instalados:

```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli

# Na pasta do projeto:
flutterfire configure            # escolha o projeto e as plataformas (android, ios, web)
firebase use --add               # escolha o mesmo projeto
firebase deploy --only firestore # publica as regras de segurança e os índices
```

O `flutterfire configure` substitui `lib/firebase_options.dart`. A partir daí o app
abre na tela de login.

## 2. Definir quem é o pastor

1. Abra o app, crie a conta do pastor com e-mail e senha e preencha o cadastro.
2. No console: **Firestore → users → (documento do pastor)**, mude o campo `role` de
   `member` para `pastor`.

Por segurança, ninguém consegue se promover a pastor pelo próprio app.

## 3. Publicar para os membros (grátis)

```bash
flutter build web --release
firebase deploy --only hosting
```

O app fica em `https://<seu-projeto>.web.app`. No celular, o membro abre o link e usa
**"Adicionar à tela inicial"**, e o app passa a funcionar como um aplicativo instalado.
Publicar na Google Play (US$ 25, pagamento único) ou na App Store (US$ 99 por ano) é opcional.

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
