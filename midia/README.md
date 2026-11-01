# Mídia · Pedras Vivas

App da equipa de mídia (Flutter, web + Android + iOS), no mesmo projeto Firebase do app da igreja.
Site: <https://pedras-vivas-midia.web.app>

| Aba | O que faz |
|---|---|
| **Ao vivo** | Ponte, OBS, transmissão (com tempo), gravação e telão; miniatura do programa do OBS; cena no ar e na prévia; luz de cada câmera; o que o telão mostra (música/Bíblia, texto); últimas mensagens. |
| **Câmera** | Cada operador escolhe a sua câmera e o ecrã inteiro vira a luz: **vermelho = NO AR**, **verde = PRÉVIA**. Mostra a última mensagem para as câmeras e mantém o ecrã ligado. |
| **Mensagens** | Conversa da equipa com destino (todos, câmeras, Holyrics, transmissão, som) e mensagens rápidas de um toque. |
| **Comandar** | Só a liderança de mídia: cenas do OBS (toque = prévia, segure = no ar, ou direto se não houver modo estúdio), TRANSIÇÃO, iniciar/parar transmissão e gravação, cena do telão, Holyrics anterior/próximo, e o estado de cada comando. |
| **Ajustes** | Câmeras (nome + fonte/cena do OBS que a mostra) e mensagens rápidas. |

## Como liga ao OBS e ao telão

```
OBS (PC da transmissão) ──ws:4455──┐
                                    ├─ ponte_midia (Node, PC da igreja) ⇄ Firestore ⇄ app de mídia
servidor do telão :8765 (Holyrics) ─┘
```

A ponte (pasta [`ponte_midia`](../ponte_midia/LEIA-ME.md)) publica `midia/estado` e `midia/previa`
e executa os pedidos de `midiaComandos`. O app nunca fala diretamente com o OBS.

## Quem entra

No app da igreja, em **Usuários**: *Equipa de mídia* (não faz parte · equipa · liderança) e
*Ponte de mídia (computador)* para a conta usada pela ponte. Pastores, presbíteros e a secretaria
veem tudo; comandar é só da liderança de mídia e da secretaria. As regras estão em
`../firestore.rules` (testes em `../firestore_tests`).

## Rodar

```bash
flutter run -d chrome --dart-define=DEMO=true   # demonstração com OBS simulado
dart format lib test && flutter analyze --fatal-infos && flutter test
```
