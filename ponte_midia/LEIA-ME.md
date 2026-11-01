# Ponte de mídia

Programa pequeno que corre no **computador da igreja** (o do Holyrics/telão) e liga:

- o **OBS** (noutro computador da rede), pelo WebSocket que já vem no OBS 28 ou mais novo;
- o **servidor do telão** (`system-web-holyrics`, http://localhost:8765);
- o **app da equipa de mídia**, pelo Firebase.

Ela envia para o app o que está no ar (cena do OBS, prévia, transmissão, gravação, câmeras,
o que o telão mostra e uma miniatura do programa) e executa o que os líderes de mídia pedem
pelo app (trocar cena, transição, iniciar/parar transmissão e gravação, cena do telão,
próximo/anterior no Holyrics).

## Instalar (uma vez)

1. **No computador do OBS:** *Ferramentas › Configurações do servidor WebSocket* → marque
   **Ativar servidor WebSocket**, deixe a porta **4455**, marque **Ativar autenticação** e
   anote a senha. Veja o IP desse computador (`ipconfig`, "Endereço IPv4").
2. **No app da igreja**, crie uma conta para a ponte (ex.: `ponte.midia@…`). Um pastor ou
   presbítero aprova em *Mais › Usuários e permissões* e marca **Ponte de mídia (computador)**.
3. **No computador da igreja**, instale o [Node.js LTS](https://nodejs.org), copie esta pasta
   (ex.: `D:\PonteMidia`) e rode `instalar.ps1` (botão direito › *Executar com o PowerShell*).
   Ele abre o `config.json`: preencha o IP e a senha do OBS e o e-mail/senha da conta da ponte.

Pronto: a ponte arranca com o Windows, escondida. O registro fica em `ponte.log`.

## config.json

| Campo | O que é |
|---|---|
| `obs.url` | `ws://IP-do-PC-do-OBS:4455` |
| `obs.senha` | senha do WebSocket do OBS |
| `telao.url` | servidor do telão (normalmente `http://localhost:8765`) |
| `firebase.email` / `senha` | conta marcada como ponte no app da igreja |
| `previa.intervaloSegundos` | de quanto em quanto tempo manda a miniatura (4 s) |

## Se algo não aparece no app

- **"Ponte desligada"**: o computador da igreja está desligado ou a ponte parou. Veja o fim de `ponte.log` e rode `instalar.ps1` de novo.
- **"OBS desconectado"**: IP/senha errados, OBS fechado, ou a Firewall do Windows do PC do OBS bloqueia a porta 4455.
- **"Telão desconectado"**: o servidor do telão (http://localhost:8765/painel) não está a correr.

## Testes

```bash
npm install && npm test   # inclui o protocolo real do obs-websocket, com e sem senha
```
