import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/links.dart';
import '../../core/pickers.dart';
import '../../core/widgets.dart';
import '../../data/models/igreja.dart';
import '../../data/providers.dart';
import '../common.dart';

class EventoFormPage extends ConsumerStatefulWidget {
  const EventoFormPage({super.key, this.id});
  final String? id;

  @override
  ConsumerState<EventoFormPage> createState() => _EventoFormPageState();
}

class _EventoFormPageState extends ConsumerState<EventoFormPage> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _place = TextEditingController();
  final _address = TextEditingController();
  final _desc = TextEditingController();
  final _responsible = TextEditingController();
  final _capacity = TextEditingController();
  final _price = TextEditingController();
  final _link = TextEditingController();
  late String _date = ymd(addDays(DateTime.now(), 7));
  String _time = '19:00';
  String? _endDate, _endTime, _deadline;
  Categoria _cat = Categoria.culto;
  EventoStatus _status = EventoStatus.planejamento;
  bool _published = true, _registration = false, _loaded = false, _saving = false;
  String _createdAt = '';

  @override
  void dispose() {
    for (final c in [_title, _place, _address, _desc, _responsible, _capacity, _price, _link]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(Evento e) {
    _title.text = e.title;
    _place.text = e.place ?? '';
    _address.text = e.address ?? '';
    _desc.text = e.description ?? '';
    _responsible.text = e.responsible ?? '';
    _capacity.text = e.capacity?.toString() ?? '';
    _price.text = e.price ?? '';
    _link.text = e.link ?? '';
    _date = ymd(e.start);
    _time = hhmm(e.start);
    _endDate = e.end == null ? null : ymd(e.end!);
    _endTime = e.end == null ? null : hhmm(e.end!);
    _deadline = e.deadline;
    _cat = e.categoria;
    _status = e.status;
    _published = e.published;
    _registration = e.registration;
    _createdAt = e.createdAt;
  }

  DateTime _at(String day, String? time) {
    final d = DateTime.parse(day);
    final (h, m) = parseHhmm(time) ?? (0, 0);
    return DateTime(d.year, d.month, d.day, h, m);
  }

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final start = _at(_date, _time);
    final end = _endTime == null ? null : _at(_endDate ?? _date, _endTime);
    if (end != null && !end.isAfter(start)) return toast(context, 'O término precisa ser depois do início.');
    setState(() => _saving = true);
    final e = Evento(
      id: widget.id ?? '',
      title: _title.text,
      start: start,
      end: end,
      place: _t(_place),
      address: _t(_address),
      description: _t(_desc),
      categoria: _cat,
      status: _status,
      published: _published,
      responsible: _t(_responsible),
      registration: _registration,
      capacity: int.tryParse(_capacity.text.trim()),
      deadline: _registration ? _deadline : null,
      price: _t(_price),
      link: _t(_link),
      createdAt: _createdAt,
    );
    String? id;
    final ok = await guard(
      context,
      () async => id = await ref.read(repoProvider).saveEvent(e),
      success: 'Evento salvo',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.go('/agenda/evento/$id');
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(roleProvider).canManageEvents) return const NoAccess(title: 'Evento');
    if (widget.id != null && !_loaded) {
      final e = ref.watch(eventProvider(widget.id!));
      if (e == null) return const AppScaffold(title: 'Evento', large: false);
      _load(e);
      _loaded = true;
    }
    return AppScaffold(
      title: widget.id == null ? 'Novo evento' : 'Editar evento',
      large: false,
      maxWidth: kFormWidth,
      leading: NavAction(label: 'Cancelar', onPressed: () => context.pop()),
      actions: [NavAction(label: _saving ? 'Salvando…' : 'Salvar', bold: true, onPressed: _saving ? null : _save)],
      slivers: [
        SliverToBoxAdapter(
          child: Form(
            key: _form,
            child: Column(
              children: [
                Section(
                  children: [
                    FieldRow(
                      controller: _title,
                      placeholder: 'Nome do evento',
                      capitalization: TextCapitalization.sentences,
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Informe o nome' : null,
                    ),
                    ChoiceRow<Categoria>(
                      label: 'Tipo',
                      value: _cat,
                      options: {for (final c in Categoria.values) c: c.label},
                      onChanged: (v) => setState(() => _cat = v ?? _cat),
                    ),
                    FieldRow(
                      controller: _desc,
                      placeholder: 'Descrição, programação, o que levar…',
                      maxLines: 6,
                      minLines: 2,
                    ),
                  ],
                ),
                Section(
                  header: 'Quando e onde',
                  children: [
                    DateRow(
                      label: 'Data',
                      value: _date,
                      clearable: false,
                      onChanged: (v) => setState(() => _date = v ?? _date),
                    ),
                    TimeRow(label: 'Início', value: _time, onChanged: (v) => setState(() => _time = v ?? _time)),
                    DateRow(label: 'Termina em', value: _endDate, onChanged: (v) => setState(() => _endDate = v)),
                    TimeRow(label: 'Término', value: _endTime, onChanged: (v) => setState(() => _endTime = v)),
                    FieldRow(controller: _place, label: 'Local', placeholder: 'Templo, sítio…'),
                    FieldRow(controller: _address, label: 'Endereço', placeholder: 'Se for fora da igreja'),
                  ],
                ),
                Section(
                  header: 'Organização',
                  children: [
                    FieldRow(controller: _responsible, label: 'Responsável', placeholder: 'Quem coordena'),
                    ChoiceRow<EventoStatus>(
                      label: 'Situação',
                      value: _status,
                      options: {for (final s in EventoStatus.values) s: s.label},
                      onChanged: (v) => setState(() => _status = v ?? _status),
                    ),
                    ListRow(
                      title: 'Publicado para todos',
                      subtitle: _published ? 'Aparece na agenda dos membros' : 'Rascunho: só a liderança vê',
                      trailing: AppSwitch(value: _published, onChanged: (v) => setState(() => _published = v)),
                    ),
                  ],
                ),
                Section(
                  header: 'Inscrições',
                  children: [
                    ListRow(
                      title: 'Aceitar inscrições pelo app',
                      trailing: AppSwitch(value: _registration, onChanged: (v) => setState(() => _registration = v)),
                    ),
                    if (_registration) ...[
                      FieldRow(
                        controller: _capacity,
                        label: 'Vagas',
                        placeholder: 'Sem limite',
                        keyboardType: TextInputType.number,
                        validator: (v) => (v ?? '').trim().isEmpty || int.tryParse(v!.trim()) != null ? null : 'Número',
                      ),
                      DateRow(
                        label: 'Inscrições até',
                        value: _deadline,
                        onChanged: (v) => setState(() => _deadline = v),
                      ),
                    ],
                    FieldRow(controller: _price, label: 'Valor', placeholder: 'Gratuito, R\$ 50…'),
                    FieldRow(
                      controller: _link,
                      label: 'Link',
                      placeholder: 'Pagamento, formulário…',
                      keyboardType: TextInputType.url,
                      validator: (v) => isValidUrl(v) ? null : 'Link inválido',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
