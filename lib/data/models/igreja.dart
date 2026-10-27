import '../../core/format.dart';

/// Tipo de atividade na agenda da igreja.
enum Categoria {
  culto('Culto'),
  ebd('Escola Bíblica'),
  oracao('Oração'),
  estudo('Estudo bíblico'),
  ensaio('Ensaio'),
  sociedade('Sociedade interna'),
  reuniao('Reunião'),
  conferencia('Conferência'),
  retiro('Retiro / acampamento'),
  social('Confraternização'),
  missao('Missão / ação social'),
  outro('Outro');

  const Categoria(this.label);
  final String label;

  static Categoria parse(String? v) => Categoria.values.firstWhere((c) => c.name == v, orElse: () => Categoria.outro);
}

/// Atividade que se repete toda semana (programação fixa da igreja).
class Programacao {
  const Programacao({
    required this.id,
    required this.weekday,
    required this.time,
    required this.title,
    this.endTime,
    this.place,
    this.description,
    this.categoria = Categoria.culto,
    this.active = true,
  });

  final String id;

  /// 1 = segunda … 7 = domingo.
  final int weekday;

  /// "19:30"
  final String time;
  final String? endTime;
  final String title;
  final String? place;
  final String? description;
  final Categoria categoria;
  final bool active;

  factory Programacao.fromMap(String id, Map<String, dynamic> m) => Programacao(
    id: id,
    weekday: (m['weekday'] as num?)?.toInt() ?? 7,
    time: m['time'] as String? ?? '19:00',
    endTime: m['endTime'] as String?,
    title: m['title'] as String? ?? '',
    place: m['place'] as String?,
    description: m['description'] as String?,
    categoria: Categoria.parse(m['categoria'] as String?),
    active: m['active'] as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {
    'weekday': weekday,
    'time': time,
    'endTime': endTime,
    'title': title.trim(),
    'place': place,
    'description': description,
    'categoria': categoria.name,
    'active': active,
  };

  /// Esta atividade na semana que começa em [monday].
  DateTime on(DateTime monday) {
    final (h, m) = parseHhmm(time) ?? (0, 0);
    final d = addDays(monday, weekday - 1);
    return DateTime(d.year, d.month, d.day, h, m);
  }
}

enum EventoStatus {
  planejamento('Em planejamento'),
  confirmado('Confirmado'),
  realizado('Realizado'),
  cancelado('Cancelado');

  const EventoStatus(this.label);
  final String label;

  static EventoStatus parse(String? v) =>
      EventoStatus.values.firstWhere((s) => s.name == v, orElse: () => EventoStatus.planejamento);
}

/// Evento da igreja, com inscrições e organização (tarefas e orçamento).
class Evento {
  const Evento({
    required this.id,
    required this.title,
    required this.start,
    this.end,
    this.place,
    this.address,
    this.description,
    this.categoria = Categoria.outro,
    this.status = EventoStatus.planejamento,
    this.published = false,
    this.responsible,
    this.registration = false,
    this.capacity,
    this.deadline,
    this.price,
    this.link,
    this.createdAt = '',
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime? end;
  final String? place;
  final String? address;
  final String? description;
  final Categoria categoria;
  final EventoStatus status;

  /// Visível para todos os membros (rascunhos só a liderança vê).
  final bool published;

  /// Nome de quem coordena.
  final String? responsible;

  /// Aceita inscrições pelo app.
  final bool registration;

  /// Vagas (null = sem limite). Passando disso, a inscrição entra na lista de espera.
  final int? capacity;

  /// Último dia para se inscrever (yyyy-MM-dd).
  final String? deadline;

  /// Valor, em texto livre ("Gratuito", "R$ 50 por pessoa").
  final String? price;
  final String? link;
  final String createdAt;

  String get day => ymd(start);
  bool get isPast => (end ?? start).isBefore(DateTime.now());

  bool registrationOpen(DateTime today) =>
      registration &&
      published &&
      status != EventoStatus.cancelado &&
      status != EventoStatus.realizado &&
      (deadline == null || deadline!.compareTo(ymd(today)) >= 0) &&
      !start.isBefore(today);

  factory Evento.fromMap(String id, Map<String, dynamic> m) => Evento(
    id: id,
    title: m['title'] as String? ?? '',
    start: parseLocal(m['start'] as String),
    end: m['end'] == null ? null : parseLocal(m['end'] as String),
    place: m['place'] as String?,
    address: m['address'] as String?,
    description: m['description'] as String?,
    categoria: Categoria.parse(m['categoria'] as String?),
    status: EventoStatus.parse(m['status'] as String?),
    published: m['published'] == true,
    responsible: m['responsible'] as String?,
    registration: m['registration'] == true,
    capacity: (m['capacity'] as num?)?.toInt(),
    deadline: m['deadline'] as String?,
    price: m['price'] as String?,
    link: m['link'] as String?,
    createdAt: m['createdAt'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'title': title.trim(),
    'start': localIso(start),
    'end': end == null ? null : localIso(end!),
    'place': place,
    'address': address,
    'description': description,
    'categoria': categoria.name,
    'status': status.name,
    'published': published,
    'responsible': responsible,
    'registration': registration,
    'capacity': capacity,
    'deadline': deadline,
    'price': price,
    'link': link,
    'createdAt': createdAt,
  };
}

/// Inscrição de uma conta num evento (events/{id}/registrations/{uid}).
class Inscricao {
  const Inscricao({
    required this.uid,
    required this.name,
    required this.createdAt,
    this.phone,
    this.guests = 0,
    this.note,
    this.checkedIn = false,
  });

  final String uid;
  final String name;
  final String? phone;

  /// Acompanhantes além da própria pessoa.
  final int guests;
  final String? note;
  final String createdAt;
  final bool checkedIn;

  int get people => 1 + guests;

  factory Inscricao.fromMap(String id, Map<String, dynamic> m) => Inscricao(
    uid: id,
    name: m['name'] as String? ?? '',
    phone: m['phone'] as String?,
    guests: (m['guests'] as num?)?.toInt() ?? 0,
    note: m['note'] as String?,
    createdAt: m['createdAt'] as String? ?? '',
    checkedIn: m['checkedIn'] == true,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'phone': phone,
    'guests': guests,
    'note': note,
    'createdAt': createdAt,
    'checkedIn': checkedIn,
  };
}

/// Divide as inscrições em confirmadas e lista de espera, pela ordem de chegada.
(List<Inscricao>, List<Inscricao>) splitWaitlist(List<Inscricao> all, int? capacity) {
  final sorted = [...all]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  if (capacity == null) return (sorted, const []);
  final ok = <Inscricao>[], wait = <Inscricao>[];
  var used = 0;
  for (final i in sorted) {
    if (used + i.people <= capacity) {
      ok.add(i);
      used += i.people;
    } else {
      wait.add(i);
    }
  }
  return (ok, wait);
}

/// Tarefa da organização de um evento.
class Tarefa {
  const Tarefa({required this.id, required this.title, this.assignee, this.due, this.done = false, this.notes});

  final String id;
  final String title;
  final String? assignee;

  /// yyyy-MM-dd
  final String? due;
  final bool done;
  final String? notes;

  factory Tarefa.fromMap(String id, Map<String, dynamic> m) => Tarefa(
    id: id,
    title: m['title'] as String? ?? '',
    assignee: m['assignee'] as String?,
    due: m['due'] as String?,
    done: m['done'] == true,
    notes: m['notes'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'title': title.trim(),
    'assignee': assignee,
    'due': due,
    'done': done,
    'notes': notes,
  };
}

/// Item do orçamento de um evento.
class Lancamento {
  const Lancamento({required this.id, required this.description, this.receita = false, this.planned = 0, this.actual});

  final String id;
  final String description;

  /// Entrada (inscrições, doações) em vez de despesa.
  final bool receita;
  final double planned;

  /// Valor realizado (null = ainda não pago/recebido).
  final double? actual;

  factory Lancamento.fromMap(String id, Map<String, dynamic> m) => Lancamento(
    id: id,
    description: m['description'] as String? ?? '',
    receita: m['receita'] == true,
    planned: (m['planned'] as num?)?.toDouble() ?? 0,
    actual: (m['actual'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'description': description.trim(),
    'receita': receita,
    'planned': planned,
    'actual': actual,
  };
}

/// Totais do orçamento: previsto e realizado, de despesas e receitas.
class Orcamento {
  Orcamento(List<Lancamento> itens)
    : despesaPrevista = _sum(itens.where((i) => !i.receita), (i) => i.planned),
      despesaRealizada = _sum(itens.where((i) => !i.receita), (i) => i.actual ?? 0),
      receitaPrevista = _sum(itens.where((i) => i.receita), (i) => i.planned),
      receitaRealizada = _sum(itens.where((i) => i.receita), (i) => i.actual ?? 0);

  final double despesaPrevista, despesaRealizada, receitaPrevista, receitaRealizada;

  double get saldoPrevisto => receitaPrevista - despesaPrevista;
  double get saldoRealizado => receitaRealizada - despesaRealizada;

  static double _sum(Iterable<Lancamento> it, double Function(Lancamento) f) => it.fold(0, (a, i) => a + f(i));
}
