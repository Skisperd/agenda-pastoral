import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/pastoral.dart';
import '../../data/models/people.dart';
import '../../data/providers.dart';
import '../../domain/models.dart';
import '../../domain/scheduler.dart';

const motivosVisita = [
  'Visita de comunhão',
  'Aconselhamento',
  'Enfermidade',
  'Bênção do lar',
  'Luto',
  'Nascimento',
  'Outro',
];

/// Escolha do dia e do horário da visita. Mostra todos os horários das janelas
/// do pastor; os que não cabem aparecem com o motivo (deslocamento, limite…).
Future<void> showAgendarSheet(BuildContext context, {required Membro member, bool byPastor = false}) => showSheet<void>(
  context,
  tall: true,
  builder: (_) => _AgendarSheet(member: member, byPastor: byPastor),
);

class _AgendarSheet extends ConsumerStatefulWidget {
  const _AgendarSheet({required this.member, required this.byPastor});
  final Membro member;
  final bool byPastor;

  @override
  ConsumerState<_AgendarSheet> createState() => _AgendarSheetState();
}

class _AgendarSheetState extends ConsumerState<_AgendarSheet> {
  DateTime? _day;
  SlotOption? _slot;
  String _motivo = motivosVisita.first;
  bool _busy = false;

  Future<void> _book() async {
    final slot = _slot;
    if (slot == null) return;
    setState(() => _busy = true);
    final ok = await guard(
      context,
      () => ref
          .read(repoProvider)
          .bookVisit(
            member: widget.member,
            uid: ref.read(uidProvider)!,
            start: slot.start,
            scheduler: ref.read(schedulerProvider),
            reason: _motivo,
            byPastor: widget.byPastor,
          ),
      success: widget.byPastor ? 'Visita marcada' : 'Pedido enviado ao pastor',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final now = DateTime.now();
    final scheduler = ref.watch(schedulerProvider);
    final windows = [
      for (final w in ref.watch(windowsProvider).value ?? const <Janela>[])
        if (w.end.isAfter(now)) w,
    ];
    final days = {for (final w in windows) ymd(w.start)}.toList()..sort();
    final day = _day ?? (days.isEmpty ? null : DateTime.parse(days.first));
    final location = GeoPoint(widget.member.lat ?? 0, widget.member.lng ?? 0);
    final slots = day == null
        ? const <SlotOption>[]
        : scheduler.slotsFor(
            location: location,
            day: day,
            windows: [for (final w in windows) w.window],
            visits: ref.watch(pastorStopsProvider),
            now: now,
          );
    return Column(
      children: [
        SheetHeader(
          title: widget.byPastor ? 'Marcar visita' : 'Agendar visita',
          action: _busy ? '…' : (widget.byPastor ? 'Marcar' : 'Pedir'),
          onAction: _slot == null || _busy ? null : _book,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  widget.byPastor
                      ? '${widget.member.name} · ${widget.member.neighborhood ?? ''}'
                      : 'Mostramos só os horários em que o pastor consegue chegar até você, '
                            'contando o deslocamento entre as visitas.',
                  style: context.text.bodyMedium,
                ),
              ),
              if (days.isEmpty)
                const EmptyState(
                  icon: CupertinoIcons.calendar_badge_minus,
                  title: 'Sem horários liberados',
                  message: 'O pastor ainda não abriu horários para visitas. Tente de novo em alguns dias.',
                )
              else ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 76,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final d in days)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _DayChip(
                            date: DateTime.parse(d),
                            selected: day != null && ymd(day) == d,
                            onTap: () => setState(() {
                              _day = DateTime.parse(d);
                              _slot = null;
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                Section(
                  header: day == null ? null : capitalize(fmtLongDate(ymd(day))),
                  children: [
                    for (final s in slots)
                      ListRow(
                        leading: Icon(
                          s.available
                              ? (identical(_slot, s) || _slot?.start == s.start
                                    ? CupertinoIcons.checkmark_circle_fill
                                    : CupertinoIcons.circle)
                              : CupertinoIcons.nosign,
                          color: s.available ? pal.accent : pal.tertiaryLabel,
                        ),
                        titleWidget: Text(
                          '${hhmm(s.start)} – ${hhmm(s.end)}',
                          style: TextStyle(
                            fontFamily: numFont,
                            fontSize: 16,
                            color: s.available ? pal.label : pal.tertiaryLabel,
                          ),
                        ),
                        subtitle: s.blockedReason,
                        onTap: s.available ? () => setState(() => _slot = s) : null,
                      ),
                  ],
                ),
                Section(
                  header: 'Motivo',
                  children: [
                    for (final m in motivosVisita)
                      ListRow(
                        title: m,
                        trailing: _motivo == m
                            ? Icon(CupertinoIcons.checkmark_alt, color: pal.accent)
                            : const SizedBox(width: 22),
                        onTap: () => setState(() => _motivo = m),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: PrimaryButton(
                    label: _slot == null
                        ? 'Escolha um horário'
                        : '${widget.byPastor ? 'Marcar' : 'Pedir'} visita às ${hhmm(_slot!.start)}',
                    loading: _busy,
                    onPressed: _slot == null ? null : _book,
                  ),
                ),
                if (!widget.byPastor)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 10, 32, 0),
                    child: Text(
                      'O pastor recebe o pedido e confirma. Você acompanha em Pastoral.',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.date, required this.selected, required this.onTap});
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Tappable(
      onTap: onTap,
      pressedOpacity: .7,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 62,
        decoration: BoxDecoration(
          color: selected ? pal.accent : pal.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? pal.accent : pal.separator, width: .5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekdayShort[date.weekday - 1].toUpperCase(),
              style: trackedLabel(selected ? pal.onAccent.withValues(alpha: .8) : pal.secondaryLabel, size: 10.5),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: TextStyle(
                fontFamily: brandFont,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1,
                color: selected ? pal.onAccent : pal.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
