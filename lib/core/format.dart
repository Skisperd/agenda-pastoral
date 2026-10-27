import 'package:intl/intl.dart';

const _locale = 'pt_BR';

/// "dom, 18 de out."
String fmtShortDate(String ymd) => DateFormat("EEE, d 'de' MMM", _locale).format(DateTime.parse(ymd));

/// "domingo, 18 de outubro de 2026"
String fmtLongDate(String ymd) => DateFormat("EEEE, d 'de' MMMM 'de' y", _locale).format(DateTime.parse(ymd));

/// "18/10/2026"
String fmtDate(String ymd) => DateFormat('dd/MM/yyyy', _locale).format(DateTime.parse(ymd));

String fmtDateTime(String iso) => DateFormat("dd/MM 'às' HH:mm", _locale).format(DateTime.parse(iso).toLocal());

/// "há 3 semanas", "hoje", "em 2 dias".
String relativeDays(String ymd, DateTime today) {
  final d = DateTime.parse(ymd);
  final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
  if (diff == 0) return 'hoje';
  if (diff == 1) return 'amanhã';
  if (diff == -1) return 'ontem';
  final n = diff.abs();
  final unit = n >= 60
      ? '${(n / 30).round()} meses'
      : n >= 14
      ? '${(n / 7).round()} semanas'
      : '$n dias';
  return diff > 0 ? 'em $unit' : 'há $unit';
}

/// Remove acentos para busca ("Cântico" casa com "cantico").
String fold(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
  const to = 'aaaaaeeeeiiiiooooouuuucnAAAAAEEEEIIIIOOOOOUUUUCN';
  final b = StringBuffer();
  for (final ch in s.runes) {
    final c = String.fromCharCode(ch);
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString().toLowerCase();
}

const musicalKeys = [
  'C', 'C#', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B', //
  'Cm', 'C#m', 'Dm', 'Ebm', 'Em', 'Fm', 'F#m', 'Gm', 'G#m', 'Am', 'Bbm', 'Bm',
];

String capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// "1:23" ou "83" -> 83 segundos. Devolve null se não for um tempo.
int? parseClock(String? v) {
  final t = (v ?? '').trim();
  if (t.isEmpty) return null;
  final parts = t.split(':');
  if (parts.length > 3 || parts.any((p) => int.tryParse(p) == null)) return null;
  var total = 0;
  for (final p in parts) {
    total = total * 60 + int.parse(p);
  }
  return total;
}

/// 83 -> "1:23"; 3725 -> "1:02:05".
String fmtClock(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  final mm = h > 0 ? m.toString().padLeft(2, '0') : '$m';
  return '${h > 0 ? '$h:' : ''}$mm:${s.toString().padLeft(2, '0')}';
}

/// Duração arredondada para falar: 1340 s -> "22 min".
String fmtMinutes(int seconds) => '${(seconds / 60).round()} min';

/// Soma dias pelo calendário, não por horas: somar [Duration] atravessando a
/// mudança de horário de verão recua um dia (domingo vira sábado).
DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// O próximo domingo a partir de [d] (o próprio [d], se for domingo).
DateTime nextSunday(DateTime d) => addDays(d, (DateTime.sunday - d.weekday) % 7);

/// Dia e hora do ensaio a partir do texto livre do culto ("Sáb. 17h30", "Sexta 19h15",
/// "24/10 às 18h", "Domingo 9h"), ou null quando não há horário. Mesma regra das
/// funções de lembrete (functions/lib/ensaio.js): dia da semana = o mais próximo antes do culto.
DateTime? rehearsalDateTime(String? text, String cultoYmd) {
  if (text == null || text.trim().isEmpty) return null;
  final t = fold(text);
  final hm = RegExp(r'(\d{1,2})\s*(?:h|:)\s*(\d{2})?').firstMatch(t);
  if (hm == null) return null;
  final hour = int.parse(hm[1]!);
  final minute = hm[2] == null ? 0 : int.parse(hm[2]!);
  if (hour > 23 || minute > 59) return null;
  final culto = DateTime.parse(cultoYmd);
  final dm = RegExp(r'\b(\d{1,2})/(\d{1,2})\b').firstMatch(t);
  if (dm != null) {
    final month = int.parse(dm[2]!);
    final year = month > culto.month + 6 ? culto.year - 1 : culto.year;
    return DateTime(year, month, int.parse(dm[1]!), hour, minute);
  }
  const days = [('dom', 7), ('seg', 1), ('ter', 2), ('qua', 3), ('qui', 4), ('sex', 5), ('sab', 6)];
  var day = culto;
  for (final (k, wd) in days) {
    if (RegExp('\\b$k').hasMatch(t)) {
      day = addDays(culto, -((culto.weekday - wd + 7) % 7));
      break;
    }
  }
  if (day == culto && RegExp(r'\bontem|vespera').hasMatch(t)) day = addDays(culto, -1);
  return DateTime(day.year, day.month, day.day, hour, minute);
}

/// "Ensaio amanhã às 19h15", "Ensaio hoje às 17h30", "Ensaio sexta às 19h15",
/// "Ensaio foi sábado". Sem horário reconhecível, devolve o texto como está.
String fmtRehearsal(String? text, String cultoYmd, DateTime today) {
  final dt = rehearsalDateTime(text, cultoYmd);
  if (dt == null) return 'Ensaio ${text?.trim() ?? ''}'.trim();
  final diff = DateTime(dt.year, dt.month, dt.day).difference(DateTime(today.year, today.month, today.day)).inDays;
  final hora = dt.minute == 0 ? '${dt.hour}h' : '${dt.hour}h${dt.minute.toString().padLeft(2, '0')}';
  final dia = DateFormat('EEEE', _locale).format(dt).replaceAll('-feira', '');
  return switch (diff) {
    0 => 'Ensaio hoje às $hora',
    1 => 'Ensaio amanhã às $hora',
    < 0 => 'Ensaio foi $dia',
    _ => 'Ensaio $dia às $hora',
  };
}

/// "2026-10-27"
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Data e hora locais sem fuso ("2026-10-27T19:30"): é como o horário aparece no
/// relógio da igreja, igual para todos os aparelhos.
String localIso(DateTime d) => '${ymd(d)}T${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Lê [localIso] (ou ISO completo) como horário local.
DateTime parseLocal(String s) {
  final d = DateTime.parse(s);
  return d.isUtc ? d.toLocal() : d;
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "19h", "19h30".
String fmtHour(DateTime d) => d.minute == 0 ? '${d.hour}h' : '${d.hour}h${d.minute.toString().padLeft(2, '0')}';

/// "19:30"
String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "19:30" -> (19, 30); null se inválido.
(int, int)? parseHhmm(String? v) {
  final m = RegExp(r'^\s*(\d{1,2})\s*[:h]\s*(\d{2})?\s*$').firstMatch(v ?? '');
  if (m == null) return null;
  final h = int.parse(m[1]!), min = int.tryParse(m[2] ?? '0') ?? 0;
  if (h > 23 || min > 59) return null;
  return (h, min);
}

const weekdayNames = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
const weekdayShort = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];

/// Segunda-feira da semana de [d].
DateTime weekStart(DateTime d) => addDays(dateOnly(d), -(d.weekday - 1));

/// "R$ 1.234,50"
String fmtMoney(num v) => NumberFormat.currency(locale: _locale, symbol: r'R$').format(v);

/// "1.234,50" ou "1234.5" -> 1234.5
double? parseMoney(String? v) {
  var t = (v ?? '').replaceAll(RegExp(r'[^\d,.-]'), '');
  if (t.isEmpty) return null;
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}

/// Só os dígitos do telefone, com DDI 55 quando faltar (para wa.me e tel:).
String? phoneDigits(String? phone) {
  final d = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.length < 8) return null;
  return d.length <= 11 ? '55$d' : d;
}

/// "(11) 98765-4321"
String fmtPhone(String? phone) {
  final d = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  final local = d.length > 11 && d.startsWith('55') ? d.substring(2) : d;
  if (local.length == 11) return '(${local.substring(0, 2)}) ${local.substring(2, 7)}-${local.substring(7)}';
  if (local.length == 10) return '(${local.substring(0, 2)}) ${local.substring(2, 6)}-${local.substring(6)}';
  return phone ?? '';
}

/// Idade em anos completos em [today].
int? ageOn(String? birth, DateTime today) {
  final b = birth == null ? null : DateTime.tryParse(birth);
  if (b == null) return null;
  var age = today.year - b.year;
  if (today.month < b.month || (today.month == b.month && today.day < b.day)) age--;
  return age;
}

/// "outubro de 2026"
String fmtMonth(DateTime d) => DateFormat("MMMM 'de' y", _locale).format(d);
