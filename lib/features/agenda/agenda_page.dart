import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/pickers.dart';
import '../../core/share.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/conteudo.dart';
import '../../data/models/igreja.dart';
import '../../data/providers.dart';
import '../common.dart';

enum _Aba { semana, eventos, programacao }

class AgendaPage extends ConsumerStatefulWidget {
  const AgendaPage({super.key, this.initialTab});
  final String? initialTab;

  @override
  ConsumerState<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends ConsumerState<AgendaPage> {
  late _Aba _aba = _Aba.values.firstWhere((a) => a.name == widget.initialTab, orElse: () => _Aba.semana);
  late DateTime _week = weekStart(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(roleProvider);
    return AppScaffold(
      title: 'Agenda',
      actions: [
        if (_aba == _Aba.semana)
          NavAction(icon: CupertinoIcons.square_arrow_up, tooltip: 'Compartilhar a semana', onPressed: _share),
        if (role.canManageEvents && _aba == _Aba.eventos)
          NavAction(
            icon: CupertinoIcons.add,
            tooltip: 'Novo evento',
            onPressed: () => context.go('/agenda/evento/novo'),
          ),
        if (role.canManageEvents && _aba == _Aba.programacao)
          NavAction(
            icon: CupertinoIcons.add,
            tooltip: 'Nova atividade',
            onPressed: () => editProgramacao(context, ref),
          ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Segmented(
              value: _aba,
              segments: const {_Aba.semana: 'Semana', _Aba.eventos: 'Eventos', _Aba.programacao: 'Programação'},
              onChanged: (v) => setState(() => _aba = v),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: switch (_aba) {
            _Aba.semana => _Semana(week: _week, onWeek: (w) => setState(() => _week = w)),
            _Aba.eventos => const _Eventos(),
            _Aba.programacao => const _Programacao(),
          },
        ),
      ],
    );
  }

  void _share() {
    final igreja = ref.read(igrejaProvider).value ?? const IgrejaConfig();
    final items = ref.read(weekAgendaProvider(_week));
    final b = StringBuffer('*${igreja.shortName} · agenda da semana*\n');
    String? day;
    for (final i in items) {
      final d = ymd(i.start);
      if (d != day) {
        b.write('\n*${capitalize(fmtShortDate(d))}*\n');
        day = d;
      }
      b.write('• ${fmtHour(i.start)} ${i.title}${i.place == null ? '' : ' (${i.place})'}\n');
    }
    if (igreja.address != null) b.write('\n📍 ${igreja.address}');
    shareText(context, b.toString().trim());
  }
}

class _Semana extends ConsumerWidget {
  const _Semana({required this.week, required this.onWeek});
  final DateTime week;
  final ValueChanged<DateTime> onWeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(weekAgendaProvider(week));
    final today = ref.watch(todayProvider);
    final days = [for (var i = 0; i < 7; i++) addDays(week, i)];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Row(
            children: [
              IconButton(icon: const Icon(CupertinoIcons.chevron_left), onPressed: () => onWeek(addDays(week, -7))),
              Expanded(
                child: Tappable(
                  onTap: () => onWeek(weekStart(today)),
                  child: Text(
                    week == weekStart(today)
                        ? 'Esta semana'
                        : '${fmtDate(ymd(week)).substring(0, 5)} a ${fmtDate(ymd(addDays(week, 6))).substring(0, 5)}',
                    textAlign: TextAlign.center,
                    style: context.text.titleMedium,
                  ),
                ),
              ),
              IconButton(icon: const Icon(CupertinoIcons.chevron_right), onPressed: () => onWeek(addDays(week, 7))),
            ],
          ),
        ),
        for (final d in days)
          if (items.any((i) => ymd(i.start) == ymd(d)))
            Section(
              header: '${capitalize(weekdayNames[d.weekday - 1])}, ${d.day}${ymd(d) == ymd(today) ? ' · hoje' : ''}',
              children: [
                for (final i in items)
                  if (ymd(i.start) == ymd(d)) AgendaRow(i),
              ],
            ),
        if (items.isEmpty) const EmptyState(icon: CupertinoIcons.calendar, title: 'Nada nesta semana'),
      ],
    );
  }
}

class _Eventos extends ConsumerWidget {
  const _Eventos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    final today = ref.watch(todayProvider);
    return AsyncView(
      ref.watch(eventsProvider),
      builder: (all) {
        final next = [
          for (final e in all)
            if (!(e.end ?? e.start).isBefore(today)) e,
        ];
        final past = [
          for (final e in all.reversed)
            if ((e.end ?? e.start).isBefore(today)) e,
        ].take(20).toList();
        Widget row(Evento e) => ListRow(
          leading: _DateBadge(e.start),
          title: e.title,
          subtitle: [
            fmtHour(e.start),
            ?e.place,
            if (!e.published) 'rascunho',
            if (e.status == EventoStatus.cancelado) 'cancelado',
          ].join(' · '),
          trailing: e.registrationOpen(today) ? Pill('Inscrições', color: context.pal.green) : null,
          onTap: () => context.go('/agenda/evento/${e.id}'),
        );
        if (all.isEmpty) {
          return EmptyState(
            icon: CupertinoIcons.star,
            title: 'Nenhum evento',
            message: role.canManageEvents ? 'Crie retiros, conferências, confraternizações e ações sociais.' : null,
            action: role.canManageEvents
                ? TintButton(
                    label: 'Novo evento',
                    icon: CupertinoIcons.add,
                    onPressed: () => context.go('/agenda/evento/novo'),
                  )
                : null,
          );
        }
        return Column(
          children: [
            Section(
              header: 'Próximos',
              children: [
                for (final e in next) row(e),
                if (next.isEmpty) const ListRow(title: 'Nenhum'),
              ],
            ),
            if (past.isNotEmpty) Section(header: 'Realizados', children: [for (final e in past) row(e)]),
          ],
        );
      },
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge(this.d);
  final DateTime d;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    const meses = ['JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', 'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ'];
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: pal.accent.withValues(alpha: .1), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(meses[d.month - 1], style: trackedLabel(pal.accent, size: 10)),
          Text(
            '${d.day}',
            style: TextStyle(
              fontFamily: brandFont,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: pal.accent,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _Programacao extends ConsumerWidget {
  const _Programacao();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manage = ref.watch(roleProvider).canManageEvents;
    return AsyncView(
      ref.watch(weeklyProvider),
      builder: (list) => Column(
        children: [
          for (final wd in [7, 1, 2, 3, 4, 5, 6])
            if (list.any((p) => p.weekday == wd))
              Section(
                header: capitalize(weekdayNames[wd - 1]),
                children: [
                  for (final p in list)
                    if (p.weekday == wd)
                      ListRow(
                        leading: IconTile(p.categoria.icon, color: p.categoria.color(context.pal)),
                        title: p.title,
                        subtitle: [
                          '${p.time.replaceAll(':', 'h').replaceAll('h00', 'h')}${p.endTime == null ? '' : ' às ${p.endTime!.replaceAll(':', 'h').replaceAll('h00', 'h')}'}',
                          ?p.place,
                          if (!p.active) 'pausada',
                        ].join(' · '),
                        onTap: manage ? () => editProgramacao(context, ref, p) : null,
                      ),
                ],
              ),
          if (list.isEmpty)
            EmptyState(
              icon: CupertinoIcons.calendar,
              title: 'Programação vazia',
              message: manage ? 'Cadastre os cultos e atividades que se repetem toda semana.' : null,
            ),
          if (manage && list.isNotEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(32, 12, 32, 0),
              child: Text(
                'Toque numa atividade para editar. Ela aparece automaticamente na agenda de todas as semanas.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

/// Folha para criar/editar uma atividade semanal.
Future<void> editProgramacao(BuildContext context, WidgetRef ref, [Programacao? p]) async {
  final title = TextEditingController(text: p?.title);
  final place = TextEditingController(text: p?.place);
  final desc = TextEditingController(text: p?.description);
  var weekday = p?.weekday ?? 7;
  String? time = p?.time ?? '19:00', end = p?.endTime;
  var cat = p?.categoria ?? Categoria.culto;
  var active = p?.active ?? true;
  final result = await showSheet<String>(
    context,
    tall: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Column(
        children: [
          SheetHeader(
            title: p == null ? 'Nova atividade' : 'Atividade',
            action: 'Salvar',
            onAction: () => Navigator.pop(c, 'salvar'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                Section(
                  children: [
                    FieldRow(
                      controller: title,
                      placeholder: 'Nome (ex.: Culto de oração)',
                      capitalization: TextCapitalization.sentences,
                    ),
                    ChoiceRow<int>(
                      label: 'Dia',
                      value: weekday,
                      options: {
                        for (final d in [7, 1, 2, 3, 4, 5, 6]) d: capitalize(weekdayNames[d - 1]),
                      },
                      onChanged: (v) => setS(() => weekday = v ?? weekday),
                    ),
                    TimeRow(label: 'Início', value: time, onChanged: (v) => setS(() => time = v)),
                    TimeRow(label: 'Término', value: end, onChanged: (v) => setS(() => end = v)),
                    ChoiceRow<Categoria>(
                      label: 'Tipo',
                      value: cat,
                      options: {for (final c in Categoria.values) c: c.label},
                      onChanged: (v) => setS(() => cat = v ?? cat),
                    ),
                    FieldRow(controller: place, label: 'Local', placeholder: 'Templo, salão…'),
                    FieldRow(controller: desc, placeholder: 'Observações', maxLines: 3),
                    ListRow(
                      title: 'Ativa',
                      trailing: AppSwitch(value: active, onChanged: (v) => setS(() => active = v)),
                    ),
                  ],
                ),
                if (p != null)
                  Section(
                    children: [
                      ListRow(title: 'Excluir atividade', destructive: true, onTap: () => Navigator.pop(c, 'excluir')),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || result == null) return;
  final repo = ref.read(repoProvider);
  if (result == 'excluir') {
    await guard(context, () => repo.deleteWeekly(p!.id), success: 'Excluída');
  } else if (title.text.trim().isNotEmpty) {
    await guard(
      context,
      () => repo.saveWeekly(
        Programacao(
          id: p?.id ?? '',
          weekday: weekday,
          time: time ?? '19:00',
          endTime: end,
          title: title.text,
          place: place.text.trim().isEmpty ? null : place.text.trim(),
          description: desc.text.trim().isEmpty ? null : desc.text.trim(),
          categoria: cat,
          active: active,
        ),
      ),
      success: 'Salvo',
    );
  }
  title.dispose();
  place.dispose();
  desc.dispose();
}
