# Pedras Vivas · app da igreja

App (Flutter, **web + Android + iOS**) da Igreja Cristã Presbiteriana Pedras Vivas, no mesmo
padrão do app dos Cânticos: Flutter + Firebase, Riverpod, go_router, visual azul e branco no
estilo iOS, modo demonstração sem Firebase e regras de segurança testadas.

Site: <https://agenda-pastoral-15bff.web.app> (no celular, “Adicionar à tela inicial” instala como app).

## O que tem

| Área | O que faz |
|---|---|
| **Início** | Próxima atividade da igreja, avisos fixados, vídeos da semana, agenda da semana, “minha escala”, visitas de hoje (pastor) ou minha visita (membro), aniversariantes da semana com botão de parabéns no WhatsApp, contato do pastor. |
| **Agenda** | *Semana*: programação fixa + eventos, navegável por semana e compartilhável no WhatsApp. *Eventos*: lista e criação. *Programação*: cultos e atividades que se repetem toda semana (EBD, cultos, oração, ensaios, sociedades internas). |
| **Eventos** | Detalhes, inscrições pelo app com vagas e **lista de espera automática**, acompanhantes, **check-in** no dia, prazo de inscrição, rascunho/publicado. Organização: **checklist de tarefas** com responsável e prazo (atrasadas em vermelho) e **orçamento** previsto × realizado com saldo. |
| **Pastoral** | Agenda de visitas: o pastor libera janelas de horário; o membro vê **só os horários em que o pastor consegue chegar**, contando o deslocamento entre visitas (regra que já existia neste projeto). Reserva em transação (sem conflito), motivo da visita, confirmação com mensagem pronta no WhatsApp, **rota do dia no Google Maps**, repetir horários na semana seguinte, ajustes (duração, folga, máximo por dia). |
| **Pessoas** | *Membros* (secretaria, pastor e conselho): cadastro completo (situação no rol, ofício, família, batismo, profissão de fé, admissão, ministérios, endereço com localização), filtros, busca, exportação, cadastros novos para conferir, **anotações pastorais reservadas**, histórico de visitas. *Liderança*: contatos de pastores, presbíteros e diáconos com WhatsApp, ligação e e-mail (é o que os membros veem). *Aniversários* do ano. |
| **Escala diaconal** | **Geração automática do mês** a partir dos cultos da programação: equilibra quem serviu menos nos últimos 60 dias, evita cultos seguidos, respeita funções e as **datas em que cada um avisou que não pode**. Santa Ceia no 1º domingo. Cada diácono **confirma ou recusa**; a coordenação vê as recusas e recebe **sugestão de substituto**. Compartilha a escala no WhatsApp. |
| **Mais** | Vídeos do YouTube (player dentro do app, título preenchido pelo próprio YouTube), mural de avisos, pedidos de oração (públicos, anônimos ou reservados ao pastor, com “vou orar” e testemunhos), PIX para dízimos e ofertas, meu cadastro, usuários e permissões, dados da igreja. |

### Funcionalidades inspiradas no mercado

Comparando com apps de gestão de igreja ([Planning Center](https://help.planningcenter.com/en/scheduling-conflicts-and-blockouts.html),
apps brasileiros como Voluts/Servus e os apps de igreja das lojas): datas de bloqueio e
confirmar/recusar na escala, substituto automático, inscrições com lista de espera e check-in,
checklist e orçamento do evento, pedidos de oração com reserva pastoral, aniversariantes,
mural de avisos, vídeos do canal e compartilhamento no WhatsApp.

## Perfis

| Perfil | Pode |
|---|---|
| Secretaria / administração | Tudo, inclusive usuários e permissões |
| Pastor | Agenda pastoral, membros, anotações pastorais, eventos, escala, usuários |
| Presbítero | Membros, eventos, programação, avisos, vídeos, pedidos reservados |
| Diácono · coordena a escala | Monta, publica e ajusta a escala diaconal |
| Diácono | Vê e confirma a própria escala, marca datas em que não pode |
| Membro | Agenda, eventos e inscrições, vídeos, avisos, contatos, visita pastoral, oração |

Qualquer pessoa cria conta (e-mail/senha ou Google) e fica **aguardando aprovação**. A primeira
conta do projeto vira administradora. Quem não tem cadastro de membro cria o próprio em “Meu
cadastro” (entra como visitante, para a secretaria conferir).

**Privacidade (LGPD):** endereço, nascimento e dados do rol só são lidos pela secretaria, pastor
e conselho. Para os membros, a agenda pastoral mostra apenas o bairro e uma coordenada
arredondada (~1 km) das outras visitas, para calcular o trajeto. Tudo isso é garantido no
servidor por `firestore.rules`, com 47 testes no emulador.

## Rodar

```bash
fvm use                                      # Flutter fixado no .fvmrc (ou use o Flutter instalado)
flutter pub get
flutter run -d chrome --dart-define=DEMO=true   # modo demonstração: escolha o perfil na entrada
flutter run -d chrome                        # app real, no projeto agenda-pastoral-15bff
flutter run -d chrome --dart-define=EMULATOR=true   # app real nos emuladores locais
```

## Testes

```bash
dart format lib test && flutter analyze --fatal-infos && flutter test   # 42 testes
cd firestore_tests && npm install && npm test                           # 47 testes das regras
```

A CI (`.github/workflows/ci.yml`) roda tudo isso, compila a versão web e, no `main`, publica
regras e site no Firebase. Configuração em [docs/FIREBASE.md](docs/FIREBASE.md).

## Onde está cada coisa

```
lib/
├── main.dart                 # Firebase ou modo demonstração
├── core/                     # perfis, rotas, tema e componentes (vindos do app dos Cânticos)
├── domain/                   # regras puras: deslocamento das visitas e gerador da escala
├── data/
│   ├── store/                # DocStore: Firestore (produção) | memória (demo e testes)
│   ├── models/               # membros, visitas, agenda/eventos, escala, conteúdo
│   ├── repository.dart       # leitura e gravação de todas as coleções
│   ├── providers.dart        # Riverpod: streams por perfil e dados derivados
│   └── demo_seed.dart        # dados de exemplo (nomes fictícios)
└── features/                 # home, agenda, eventos, pastoral, pessoas, escala, vídeos, avisos, oração…
firestore.rules               # permissões por perfil, no servidor
firestore_tests/              # testes das regras no emulador
```
