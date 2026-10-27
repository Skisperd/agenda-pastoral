import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/links.dart';
import '../../core/pickers.dart';
import '../../core/share.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/pastoral.dart';
import '../../data/models/people.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../common.dart';
import 'agendar_sheet.dart';

enum _Aba { visitas, horarios, ajustes }

/// Agenda pastoral: o pastor libera horários e vê as visitas; o membro marca a
/// sua visita só nos horários em que o pastor consegue chegar.
class PastoralPage extends ConsumerStatefulWidget {
  const PastoralPage({super.key});

  @override
  ConsumerState<PastoralPage> createState() => _PastoralPageState();
}

class _PastoralPageState extends ConsumerState<PastoralPage> {
  _Aba _aba = _Aba.visitas;
  late DateTime _week = weekStart(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(roleProvider);
    if (!role.isPastoral) return const _MembroPastoral();
    return AppScaffold(
      title: 'Agenda pastoral',
      actions: [
        NavAction(icon: CupertinoIcons.add, tooltip: 'Marcar visita', onPressed: () => _marcarParaMembro(context)),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Segmented(
              value: _aba,
              segments: const {_Aba.visitas: 'Visitas', _Aba.horarios: 'Horários', _Aba.ajustes: 'Ajustes'},
              onChanged: (v) => setState(() => _aba = v),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: switch (_aba) {
            _Aba.visitas => const _Visitas(),
            _Aba.horarios => _Horarios(week: _week, onWeek: (w) => setState(() => _week = w)),
            _Aba.ajustes => const _Ajustes(),
          },
        ),
      ],
    );
  }

  Future<void> _marcarParaMembro(BuildContext context) async {
    final members = [
      for (final m in ref.read(membersProvider).value ?? const <Membro>[])
        if (m.hasLocation) m,
    ];
    var q = '';
    final picked = await showSheet<Membro>(
      context,
      tall: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          final shown = [
            for (final m in members)
              if (fold(m.name).contains(fold(q))) m,
          ];
          return Column(
            children: [
              const SheetHeader(title: 'Visitar quem?'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SearchField(autofocus: true, onChanged: (v) => setS(() => q = v)),
              ),
              Expanded(
                child: ListView(
                  children: [
                    Section(
                      footer: 'Só aparecem cadastros com endereço localizado.',
                      children: [
                        for (final m in shown)
                          ListRow(
                            leading: Initials(m.name, size: 32),
                            title: m.name,
                            subtitle: m.neighborhood,
                            onTap: () => Navigator.pop(c, m),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
    if (picked != null && context.mounted) await showAgendarSheet(context, member: picked, byPastor: true);
  }
}

class _Visitas extends ConsumerWidget {
  const _Visitas();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ymd(ref.watch(todayProvider));
    return AsyncView(
      ref.watch(visitsProvider),
      builder: (all) {
        final upcoming = [
          for (final v in all)
            if (v.status.active && v.day.compareTo(today) >= 0) v,
        ];
        final past = [
          for (final v in all.reversed)
            if (v.day.compareTo(today) < 0 && v.status != VisitaStatus.cancelada) v,
        ].take(15).toList();
        final byDay = <String, List<Visita>>{};
        for (final v in upcoming) {
          byDay.putIfAbsent(v.day, () => []).add(v);
        }
        if (upcoming.isEmpty && past.isEmpty) {
          return const EmptyState(
            icon: CupertinoIcons.house,
            title: 'Nenhuma visita marcada',
            message: 'Libere horários na aba Horários. Os membros escolhem só os horários em que você consegue chegar.',
          );
        }
        return Column(
          children: [
            for (final e in byDay.entries)
              Section(
                header: capitalize(fmtShortDate(e.key)) + (e.key == today ? ' · hoje' : ''),
                trailing: e.value.length > 1 || e.value.first.address != null
                    ? NavAction(label: 'Rota do dia', onPressed: () => _rota(context, e.value))
                    : null,
                children: [for (final v in e.value) _VisitaRow(v)],
              ),
            if (past.isNotEmpty)
              Section(header: 'Anteriores', children: [for (final v in past) _VisitaRow(v, past: true)]),
          ],
        );
      },
    );
  }

  /// Abre o Google Maps com as visitas do dia em ordem.
  void _rota(BuildContext context, List<Visita> vs) {
    final pts = [for (final v in vs) v.address ?? '${v.lat},${v.lng}'];
    final q = {
      'api': '1',
      'destination': pts.last,
      'travelmode': 'driving',
      if (pts.length > 1) 'waypoints': pts.sublist(0, pts.length - 1).join('|'),
    };
    openUrl(context, Uri.https('www.google.com', '/maps/dir/', q).toString());
  }
}

class _VisitaRow extends ConsumerWidget {
  const _VisitaRow(this.v, {this.past = false});
  final Visita v;
  final bool past;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    final color = switch (v.status) {
      VisitaStatus.pendente => pal.orange,
      VisitaStatus.confirmada => pal.green,
      VisitaStatus.realizada => pal.indigo,
      VisitaStatus.cancelada => pal.gray,
    };
    return ListRow(
      leading: SizedBox(
        width: 50,
        child: Text(
          hhmm(v.start),
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: numFont, fontWeight: FontWeight.w700, color: pal.label),
        ),
      ),
      title: v.memberName,
      subtitle: [if (past) fmtDate(v.day), v.neighborhood.split(' · ').first, ?v.reason].join(' · '),
      trailing: Pill(v.status == VisitaStatus.pendente ? 'Confirmar' : v.status.label, color: color),
      onTap: () => _acoes(context, ref),
    );
  }

  Future<void> _acoes(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(repoProvider);
    final a = await showActionSheet<String>(
      context,
      title: '${v.memberName} · ${capitalize(fmtShortDate(v.day))} às ${fmtHour(v.start)}',
      message: [?v.address, ?v.reason].join('\n'),
      actions: [
        if (v.status == VisitaStatus.pendente)
          const SheetAction('Confirmar visita', 'confirmar', icon: CupertinoIcons.checkmark_alt),
        if (v.status == VisitaStatus.confirmada)
          const SheetAction('Marcar como realizada', 'realizada', icon: CupertinoIcons.checkmark_seal),
        if (v.phone != null) const SheetAction('WhatsApp', 'whats', icon: CupertinoIcons.chat_bubble_text),
        if (v.address != null) const SheetAction('Abrir no mapa', 'mapa', icon: CupertinoIcons.map),
        const SheetAction('Ver cadastro', 'cadastro', icon: CupertinoIcons.person),
        if (v.status.active && v.status != VisitaStatus.realizada)
          const SheetAction('Cancelar visita', 'cancelar', destructive: true),
      ],
    );
    if (a == null || !context.mounted) return;
    switch (a) {
      case 'confirmar':
        await guard(context, () => repo.setVisitStatus(v.id, VisitaStatus.confirmada), success: 'Visita confirmada');
        if (v.phone != null && context.mounted) {
          await openWhatsApp(
            context,
            v.phone!,
            text:
                'Olá, ${v.memberName.split(' ').first}! Confirmo a visita pastoral em '
                '${fmtShortDate(v.day)} às ${fmtHour(v.start)}. Até lá!',
          );
        }
      case 'realizada':
        await guard(context, () => repo.setVisitStatus(v.id, VisitaStatus.realizada), success: 'Registrada');
      case 'whats':
        await openWhatsApp(context, v.phone!);
      case 'mapa':
        await openUrl(
          context,
          Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': v.address}).toString(),
        );
      case 'cadastro':
        context.go('/pessoas/${v.memberId}');
      case 'cancelar':
        if (await confirm(context, 'Cancelar a visita?', ok: 'Cancelar visita', destructive: true) && context.mounted) {
          await guard(context, () => repo.cancelVisit(v, byPastor: true), success: 'Visita cancelada');
        }
    }
  }
}

class _Horarios extends ConsumerWidget {
  const _Horarios({required this.week, required this.onWeek});
  final DateTime week;
  final ValueChanged<DateTime> onWeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(windowsProvider).value ?? const <Janela>[];
    final next = addDays(week, 7);
    final windows = [
      for (final w in all)
        if (!w.start.isBefore(week) && w.start.isBefore(next)) w,
    ];
    final visits = ref.watch(visitsProvider).value ?? const <Visita>[];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Row(
            children: [
              IconButton(icon: const Icon(CupertinoIcons.chevron_left), onPressed: () => onWeek(addDays(week, -7))),
              Expanded(
                child: Text(
                  'Semana de ${fmtDate(ymd(week)).substring(0, 5)} a ${fmtDate(ymd(addDays(week, 6))).substring(0, 5)}',
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium,
                ),
              ),
              IconButton(icon: const Icon(CupertinoIcons.chevron_right), onPressed: () => onWeek(addDays(week, 7))),
            ],
          ),
        ),
        Section(
          footer: 'Os membros só veem horários dentro destas janelas, já descontando o deslocamento.',
          children: [
            for (final w in windows)
              ListRow(
                leading: IconTile(CupertinoIcons.clock_fill, color: context.pal.accent),
                title: capitalize(fmtShortDate(ymd(w.start))),
                subtitle:
                    '${fmtHour(w.start)} às ${fmtHour(w.end)} · '
                    '${visits.where((v) => v.status.active && v.day == ymd(w.start)).length} visita(s)',
                trailing: Tappable(
                  onTap: () => guard(context, () => ref.read(repoProvider).removeWindow(w.id)),
                  child: Icon(CupertinoIcons.trash, size: 19, color: context.pal.red),
                ),
              ),
            if (windows.isEmpty) const ListRow(title: 'Nenhum horário nesta semana'),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: PrimaryButton(label: 'Liberar horário', icon: CupertinoIcons.add, onPressed: () => _add(context, ref)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: TintButton(
            label: 'Repetir esta semana na próxima',
            icon: CupertinoIcons.arrow_2_squarepath,
            large: true,
            expand: true,
            onPressed: windows.isEmpty
                ? null
                : () async {
                    var n = 0;
                    final ok = await guard(context, () async => n = await ref.read(repoProvider).copyWeek(all, week));
                    if (ok && context.mounted) {
                      toast(context, n == 0 ? 'A próxima semana já tem esses horários' : '$n horário(s) copiados');
                      onWeek(addDays(week, 7));
                    }
                  },
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final today = dateOnly(DateTime.now());
    final d = await pickDate(context, initial: week.isBefore(today) ? today : week, first: today);
    if (d == null || !context.mounted) return;
    final s = await pickTime(context, initial: const TimeOfDay(hour: 17, minute: 0));
    if (s == null || !context.mounted) return;
    final e = await pickTime(
      context,
      initial: TimeOfDay(hour: (s.hour + 4).clamp(0, 23), minute: s.minute),
    );
    if (e == null || !context.mounted) return;
    await guard(
      context,
      () => ref
          .read(repoProvider)
          .addWindow(
            DateTime(d.year, d.month, d.day, s.hour, s.minute),
            DateTime(d.year, d.month, d.day, e.hour, e.minute),
          ),
      success: 'Horário liberado',
    );
  }
}

class _Ajustes extends ConsumerWidget {
  const _Ajustes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(scheduleSettingsProvider).value ?? const ScheduleSettings();
    Future<void> save(ScheduleSettings n) => guard(context, () => ref.read(repoProvider).saveScheduleSettings(n));
    ScheduleSettings make({int? dur, int? buf, int? step, int? max}) => ScheduleSettings(
      visitDuration: Duration(minutes: dur ?? s.visitDuration.inMinutes),
      buffer: Duration(minutes: buf ?? s.buffer.inMinutes),
      slotStep: Duration(minutes: step ?? s.slotStep.inMinutes),
      maxVisitsPerDay: max ?? s.maxVisitsPerDay,
    );
    return Section(
      footer:
          'O deslocamento é estimado pela distância entre os endereços (como um trajeto de carro na cidade, '
          'a ~25 km/h) mais a folga. É calculado no próprio aparelho, sem custo.',
      children: [
        ChoiceRow<int>(
          label: 'Duração da visita',
          value: s.visitDuration.inMinutes,
          options: const {30: '30 min', 45: '45 min', 60: '1 hora', 90: '1h30', 120: '2 horas'},
          onChanged: (v) => save(make(dur: v)),
        ),
        ChoiceRow<int>(
          label: 'Folga entre visitas',
          value: s.buffer.inMinutes,
          options: const {0: 'Nenhuma', 5: '5 min', 10: '10 min', 15: '15 min', 20: '20 min', 30: '30 min'},
          onChanged: (v) => save(make(buf: v)),
        ),
        ChoiceRow<int>(
          label: 'Horários a cada',
          value: s.slotStep.inMinutes,
          options: const {15: '15 min', 30: '30 min', 60: '1 hora'},
          onChanged: (v) => save(make(step: v)),
        ),
        ChoiceRow<int>(
          label: 'Máximo por dia',
          value: s.maxVisitsPerDay,
          options: const {
            1: '1 visita',
            2: '2 visitas',
            3: '3 visitas',
            4: '4 visitas',
            5: '5 visitas',
            6: '6 visitas',
          },
          onChanged: (v) => save(make(max: v)),
        ),
      ],
    );
  }
}

/// Visão do membro: pedir visita e acompanhar as suas.
class _MembroPastoral extends ConsumerWidget {
  const _MembroPastoral();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(myMemberProvider);
    final now = DateTime.now();
    final mine = ref.watch(visitsProvider).value ?? const <Visita>[];
    final upcoming = [
      for (final v in mine)
        if (v.status.active && v.end.isAfter(now)) v,
    ];
    final past = [
      for (final v in mine.reversed)
        if (!v.end.isAfter(now) || !v.status.active) v,
    ];
    final member = me.value;
    final pastores = [
      for (final m in ref.watch(officersProvider).value ?? const <Membro>[])
        if (m.oficio?.name == 'pastor') m,
    ];
    return AppScaffold(
      title: 'Visita pastoral',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(
              'Escolha um horário e o pastor vai até a sua casa. O app só mostra os horários em que ele '
              'consegue chegar, contando o trajeto entre uma visita e outra.',
              style: context.text.bodyMedium,
            ),
          ),
        ),
        if (member == null || !member.hasLocation)
          SliverToBoxAdapter(
            child: NoticeCard(
              icon: CupertinoIcons.location_fill,
              title: 'Complete seu cadastro',
              message: 'Precisamos do seu endereço para calcular o trajeto do pastor.',
              color: context.pal.orange,
              onTap: () => context.go('/mais/cadastro'),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: PrimaryButton(
                label: 'Agendar visita',
                icon: CupertinoIcons.calendar_badge_plus,
                onPressed: () => showAgendarSheet(context, member: member),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Section(
            header: 'Minhas visitas',
            children: [
              for (final v in upcoming)
                ListRow(
                  leading: IconTile(
                    CupertinoIcons.house_fill,
                    color: v.status == VisitaStatus.confirmada ? context.pal.green : context.pal.orange,
                  ),
                  title: '${capitalize(fmtShortDate(v.day))} às ${fmtHour(v.start)}',
                  subtitle: [v.status.label, ?v.reason].join(' · '),
                  trailing: TintButton(
                    label: 'Cancelar',
                    color: context.pal.red,
                    onPressed: () async {
                      if (!await confirm(context, 'Cancelar a visita?', ok: 'Cancelar visita', destructive: true)) {
                        return;
                      }
                      if (context.mounted) {
                        await guard(
                          context,
                          () => ref.read(repoProvider).cancelVisit(v, byPastor: false),
                          success: 'Visita cancelada',
                        );
                      }
                    },
                  ),
                ),
              if (upcoming.isEmpty) const ListRow(title: 'Nenhuma visita marcada'),
            ],
          ),
        ),
        if (past.isNotEmpty)
          SliverToBoxAdapter(
            child: Section(
              header: 'Anteriores',
              children: [
                for (final v in past.take(10))
                  ListRow(title: '${fmtDate(v.day)} às ${fmtHour(v.start)}', value: v.status.label),
              ],
            ),
          ),
        if (pastores.isNotEmpty)
          SliverToBoxAdapter(
            child: Section(header: 'Falar com o pastor', children: [for (final p in pastores) ContactRow(p)]),
          ),
      ],
    );
  }
}
