import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'format.dart';
import 'widgets.dart';

Future<DateTime?> pickDate(BuildContext context, {DateTime? initial, DateTime? first, DateTime? last}) {
  final now = DateTime.now();
  final init = initial ?? now;
  final f = first ?? DateTime(1900);
  final l = last ?? DateTime(now.year + 5);
  return showDatePicker(
    context: context,
    initialDate: init.isBefore(f) ? f : (init.isAfter(l) ? l : init),
    firstDate: f,
    lastDate: l,
    locale: const Locale('pt', 'BR'),
  );
}

Future<TimeOfDay?> pickTime(BuildContext context, {TimeOfDay? initial}) => showTimePicker(
  context: context,
  initialTime: initial ?? const TimeOfDay(hour: 19, minute: 0),
  builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
);

String fmtTimeOfDay(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Linha de formulário que abre o seletor de data (yyyy-MM-dd ou vazio).
class DateRow extends StatelessWidget {
  const DateRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.first,
    this.last,
    this.clearable = true,
  });
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;
  final DateTime? first;
  final DateTime? last;
  final bool clearable;

  @override
  Widget build(BuildContext context) => ListRow(
    title: label,
    value: value == null ? 'Escolher' : fmtDate(value!),
    trailing: value != null && clearable
        ? Tappable(
            onTap: () => onChanged(null),
            child: Icon(CupertinoIcons.xmark_circle_fill, size: 18, color: context.pal.tertiaryLabel),
          )
        : null,
    onTap: () async {
      final d = await pickDate(
        context,
        initial: value == null ? null : DateTime.tryParse(value!),
        first: first,
        last: last,
      );
      if (d != null) onChanged(ymd(d));
    },
  );
}

/// Linha de formulário que abre o seletor de hora ("19:30").
class TimeRow extends StatelessWidget {
  const TimeRow({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => ListRow(
    title: label,
    value: value ?? 'Escolher',
    onTap: () async {
      final hm = parseHhmm(value);
      final t = await pickTime(
        context,
        initial: hm == null ? null : TimeOfDay(hour: hm.$1, minute: hm.$2),
      );
      if (t != null) onChanged(fmtTimeOfDay(t));
    },
  );
}

/// Escolha de uma opção numa folha de ações, mostrada como linha de formulário.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.placeholder = 'Escolher',
  });
  final String label;
  final T? value;
  final Map<T, String> options;
  final ValueChanged<T?> onChanged;
  final String placeholder;

  @override
  Widget build(BuildContext context) => ListRow(
    title: label,
    value: value == null ? placeholder : options[value],
    onTap: () async {
      final v = await showActionSheet<T>(
        context,
        title: label,
        actions: [for (final e in options.entries) SheetAction(e.value, e.key)],
      );
      if (v != null) onChanged(v);
    },
  );
}
