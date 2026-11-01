import '../core/format.dart';
import 'models/boletim.dart';
import 'models/conteudo.dart';
import 'models/igreja.dart';
import 'models/pg.dart';
import 'repository.dart';
import 'store/doc_store.dart';

/// Dados da Pedras Vivas tirados do boletim de 25 a 31 de outubro de 2026 e do
/// folheto dos Pequenos Grupos. Usados na configuração inicial e no modo demonstração.
abstract final class DadosIniciais {
  static const igreja = IgrejaConfig(
    address: 'Rua do Sistelo 199, Rio Tinto - Porto',
    site: 'https://igrejapedrasvivas.pt',
    youtube: 'https://www.youtube.com/@pedrasvivas',
    banco: 'Banco BPI',
    iban: 'PT50 0010 0000 5558 8510 0010 2',
    swift: 'BBPIPTPL',
    ofertas: [
      ('Dízimo', '+ 0,01 €'),
      ('Ar condicionado', '+ 0,02 €'),
      ('Missões', '+ 0,03 €'),
      ('Novo Espaço / Obras', '+ 0,07 €'),
    ],
  );

  /// Domingo: (dia, início, fim, título, categoria, local)
  static const List<(int, String, String?, String, Categoria, String?)> programacao = [
    (7, '09:00', '10:00', 'Escola Bíblica Dominical', Categoria.ebd, null),
    (7, '10:00', '10:20', 'Pequeno-almoço', Categoria.social, null),
    (7, '10:30', null, 'Culto solene', Categoria.culto, null),
    (7, '17:00', null, 'Reunião de oração', Categoria.oracao, null),
  ];

  static const grupos = [
    Grupo(id: 'sao-mamede', local: 'São Mamede', weekday: 4, time: '19:30', lider: 'Marco'),
    Grupo(id: 'castelo-da-maia', local: 'Castêlo da Maia', weekday: 4, time: '20:00', lider: 'Caio'),
    Grupo(id: 'pacos-de-ferreira', local: 'Paços de Ferreira', weekday: 5, time: '19:30', lider: 'Nathan'),
    Grupo(id: 'porto', local: 'Porto', weekday: 5, time: '20:00', lider: 'Pr. Léo'),
    Grupo(id: 'gaia', local: 'Gaia', weekday: 5, time: '20:00', lider: 'Ronaldo'),
    Grupo(id: 'rio-tinto', local: 'Rio Tinto', weekday: 5, time: '20:00', lider: 'Rui'),
    Grupo(id: 'trofa', local: 'Trofa', weekday: 5, time: '20:00', lider: 'Lucas'),
  ];

  static const pg = PgConfig(contatoNome: 'presbítero Roberto', estudoAtual: 'atos-14-01');

  static const boletim = Boletim(
    id: '2026-10-25',
    inicio: '2026-10-25',
    publicado: true,
    avisos: [
      ItemBoletim(
        titulo: 'Arrecadação de alimentos',
        texto: 'Contribua com alimentos não perecíveis para os cabazes destinados aos irmãos em necessidade.',
        destaque: true,
      ),
      ItemBoletim(
        titulo: 'Jejum',
        texto: 'Durante o mês de novembro, somos convidados a jejuar pela nossa igreja e denominação.',
      ),
      ItemBoletim(titulo: 'Pequenos Grupos', texto: '29 e 30/10.'),
      ItemBoletim(titulo: 'Curso NUTRA', texto: '2.ª fase: 02 e 07/11.'),
      ItemBoletim(
        titulo: 'Assembleia Extraordinária',
        texto: '15/11. 8h30: assinatura da lista de presença. 9h: início da assembleia.',
      ),
    ],
    oracao: [
      ItemBoletim(
        titulo: 'Crescimento Espiritual da Igreja Pedras Vivas',
        texto: 'para sempre sermos gratos por nossa redenção em Cristo.',
      ),
      ItemBoletim(
        titulo: 'Por bênçãos materiais',
        texto:
            'desafios da Expansão da IPV em 2026, 2027 e 2028. Enfermos e grávidas da igreja. '
            'Por aqueles que buscam emprego ou melhores ordenados.',
      ),
      ItemBoletim(titulo: 'ICPP', texto: 'ICPPV Lisboa e ICP Évora.'),
      ItemBoletim(titulo: 'Portugal', texto: 'crise habitacional.'),
      ItemBoletim(
        titulo: 'Missões',
        texto: 'Pr. Cláudio, Cássia, João Pedro e Maria Fernanda — Missionários APMT na Nova Zelândia.',
      ),
      ItemBoletim(titulo: 'Agradecimentos', texto: 'visto Pr. Moisés e família.'),
    ],
    estudos: [
      EstudoFrente('Escola Dominical', 'O Pai nosso'),
      EstudoFrente('Culto solene', '1 Pedro'),
      EstudoFrente('Curso de Teologia', 'Doutrina de Cristo'),
      EstudoFrente('Pequenos grupos', 'Atos 14'),
    ],
  );
}

extension ConfiguracaoInicial on Repository {
  /// Aplica os dados iniciais sem apagar nada: só preenche o que ainda está vazio.
  /// [estudos] é a série de Atos (assets/estudos/atos.json). Devolve o que foi criado.
  Future<List<String>> aplicarDadosIniciais({Map<String, dynamic>? estudos}) async {
    final feito = <String>[];
    final writes = <DocWrite>[];
    final igreja = await store.getDoc('${Col.config}/igreja');
    if (igreja == null || (igreja.data['iban'] == null && igreja.data['address'] == null)) {
      writes.add(
        DocWrite(
          '${Col.config}/igreja',
          {...DadosIniciais.igreja.toMap(), ...?igreja?.data}..removeWhere((_, v) => v == null),
        ),
      );
      feito.add('dados da igreja');
    }
    if ((await store.watchCollection(Col.weekly).first).isEmpty) {
      for (final (i, (wd, t, fim, titulo, cat, local)) in DadosIniciais.programacao.indexed) {
        writes.add(
          DocWrite(
            '${Col.weekly}/inicial-$i',
            Programacao(
              id: '',
              weekday: wd,
              time: t,
              endTime: fim,
              title: titulo,
              categoria: cat,
              place: local,
            ).toMap(),
            merge: false,
          ),
        );
      }
      feito.add('programação de domingo');
    }
    if ((await store.watchCollection(Col.grupos).first).isEmpty) {
      for (final g in DadosIniciais.grupos) {
        writes.add(DocWrite('${Col.grupos}/${g.id}', g.toMap(), merge: false));
      }
      feito.add('${DadosIniciais.grupos.length} pequenos grupos');
    }
    if (await store.getDoc('${Col.config}/pg') == null) {
      writes.add(DocWrite('${Col.config}/pg', DadosIniciais.pg.toMap(), merge: false));
    }
    if (await store.getDoc('${Col.boletins}/${DadosIniciais.boletim.id}') == null) {
      writes.add(
        DocWrite('${Col.boletins}/${DadosIniciais.boletim.id}', {
          ...DadosIniciais.boletim.toMap(),
          'atualizadoEm': nowIso(),
        }, merge: false),
      );
      feito.add('boletim de ${DadosIniciais.boletim.periodo}');
    }
    if (writes.isNotEmpty) await store.batch(writes);
    if (estudos != null && (await store.watchCollection(Col.estudos).first).isEmpty) {
      feito.add('${await importEstudos(estudos)} estudos de Atos');
    }
    return feito;
  }
}

/// Para o domingo de [d] ficar em [DadosIniciais.boletim] no modo demonstração.
Boletim boletimDemo(DateTime d) => DadosIniciais.boletim.paraSemana(ymd(domingoDe(d)));
