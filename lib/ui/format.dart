const _weekdays = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
const _weekdaysShort = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

String two(int n) => n.toString().padLeft(2, '0');

String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String ddmm(DateTime d) => '${two(d.day)}/${two(d.month)}';

String weekday(DateTime d) => _weekdays[d.weekday - 1];

String dayLabel(DateTime d) => '${_weekdaysShort[d.weekday - 1]} ${ddmm(d)}';

String fullDay(DateTime d) {
  final w = weekday(d);
  return '${w[0].toUpperCase()}${w.substring(1)}, ${ddmm(d)}';
}

String range(DateTime a, DateTime b) => '${hhmm(a)} – ${hhmm(b)}';

/// Segunda-feira da semana de [d].
DateTime weekStart(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));
