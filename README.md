# Agenda Pastoral

App para os membros da igreja agendarem visitas do pastor, levando em conta o tempo
de deslocamento entre uma visita e outra.

- O **pastor** libera janelas de atendimento por dia (ex.: esta semana das 17h às 22h,
  a próxima das 12h às 17h). Um botão repete a semana na seguinte.
- O **membro** escolhe o dia e vê **só os horários em que o pastor consegue chegar**,
  considerando o deslocamento a partir da visita anterior e até a seguinte.
- Ao reservar, o pastor recebe um aviso e confirma ou recusa a visita.

Exemplo: o Irmão João (Santo Amaro, Zona Sul) tem visita das 17h às 18h. Para a
Irmã Maria (Santana, Zona Norte), a ~64 min de distância, o primeiro horário livre é
19h30. Para o Irmão Pedro (Campo Belo, também Zona Sul), já é 18h30.

Stack: **Flutter** (Android, iOS e web com um só código), **Firebase** (Auth, Firestore,
Hosting) e **Patrol** para testes de ponta a ponta. Tudo dentro de planos gratuitos.

## Modos de execução

| Comando | O que abre |
|---|---|
| `flutter run` (sem Firebase configurado) | Modo demonstração, com dados de exemplo em memória |
| `flutter run` (depois do `flutterfire configure`) | App real: login, cadastro e dados no Firestore |
| `flutter run --dart-define=EMULATORS=true` | App real nos emuladores locais do Firebase |
| `flutter run --dart-define=DEMO=true` | Força o modo demonstração |

Para ligar no Firebase, siga [docs/FIREBASE.md](docs/FIREBASE.md).

## Testes

```bash
flutter test                         # regra de deslocamento, fluxo das telas e camada Firestore

dart pub global activate patrol_cli  # Patrol, ponta a ponta
patrol test -t integration_test/agendamento_test.dart --device chrome --web-headless
patrol test -t integration_test/agendamento_test.dart       # emulador/celular conectado

cd firestore_tests && npm install && npm test               # regras de segurança no emulador
```

- Em servidor sem GPU, acrescente ao Patrol web:
  `--web-browser-args '["--enable-unsafe-swiftshader"]' --web-locale pt-BR`.
- Para o Patrol no Android/iOS nativo, faça uma vez a configuração descrita em
  <https://patrol.leancode.co/getting-started>.
- A CI (`.github/workflows/ci.yml`) roda tudo isso a cada push.

## Onde está cada coisa

| Caminho | O que faz |
|---|---|
| `lib/domain/scheduler.dart` | Regra central: gera os horários e explica por que cada um está bloqueado |
| `lib/domain/travel_time.dart` | Estimativa de deslocamento (linha reta × 1,4 a 25 km/h, grátis e offline) |
| `lib/data/agenda_store.dart` | Interface da agenda e a versão em memória (demonstração) |
| `lib/firebase/firestore_agenda_store.dart` | Versão Firestore, com reserva em transação |
| `lib/firebase/` | Login, cadastro (endereço → coordenadas) e roteamento por perfil |
| `lib/ui/` | Telas do pastor e do membro |
| `test/` | Testes unitários, de widget e da camada Firestore |
| `integration_test/` | Testes Patrol |
| `firestore.rules`, `firestore_tests/` | Regras de segurança e seus testes |

## Parâmetros (em `ScheduleSettings`)

- Duração da visita: 1h
- Folga somada ao deslocamento: 10 min
- Horários oferecidos de 30 em 30 min
- Máximo de 4 visitas por dia
