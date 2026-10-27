import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/pickers.dart';
import '../../core/roles.dart';
import '../../core/share.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/escala.dart';
import '../../data/providers.dart';

/// Escala diaconal: próximos cultos, minha escala e indisponibilidades.
class EscalaPage extends ConsumerWidget {
  const EscalaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    final user = ref.watch(currentUserProvider).value;
    final today = ymd(ref.watch(todayProvider));
    final mine = ref.watch(myEscalasProvider);
    return AppScaffold(
      title: 'Escala diaconal',
      previousPageTitle: 'Mais',
      actions: [
        NavAction(icon: CupertinoIcons.square_arrow_up, tooltip: 'Compartilhar', onPressed: () => _share(context, ref)),
        if (role.canManageEscala)
          NavAction(icon: CupertinoIcons.add, tooltip: 'Nova escala', onPressed: () => _nova(context, ref)),
      ],
      slivers: [
        if (role.canManageEscala)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: PrimaryButton(
                label: 'Gerar escala do mês',
                icon: CupertinoIcons.wand_stars,
                onPressed: () => context.go('/mais/escala/gerar'),
              ),
            ),
          ),
        if (mine.isNotEmpty)
          SliverToBoxAdapter(
            child: Section(
              header: 'Minhas próximas escalas',
              children: [for (final e in mine) _EscalaRow(e, memberId: user?.memberId)],
            ),
          ),
        SliverToBoxAdapter(
          child: AsyncView(
            ref.watch(escalasProvider),
            builder: (all) {
              final next = [
                for (final e in all)
                  if (e.date.compareTo(today) >= 0) e,
              ];
              final past = [
                for (final e in all.reversed)
                  if (e.date.compareTo(today) < 0) e,
              ].take(8).toList();
              return Column(
                children: [
                  Section(
                    header: 'Próximos cultos',
                    children: [
                      for (final e in next) _EscalaRow(e),
                      if (next.isEmpty)
                        ListRow(
                          title: role.canManageEscala
                              ? 'Nenhuma escala. Use "Gerar escala do mês".'
                              : 'A escala ainda não foi publicada.',
                        ),
                    ],
                  ),
                  if (past.isNotEmpty) Section(header: 'Anteriores', children: [for (final e in past) _EscalaRow(e)]),
                ],
              );
            },
          ),
        ),
        if (user?.memberId != null && (role.isDiacono || role.canManageEscala))
          const SliverToBoxAdapter(child: _Indisponivel()),
      ],
    );
  }

  Future<void> _nova(BuildContext context, WidgetRef ref) async {
    final d = await pickDate(context, first: dateOnly(DateTime.now()));
    if (d == null || !context.mounted) return;
    final title = await promptText(context, title: 'Culto', placeholder: 'Ex.: Culto de domingo · noite', ok: 'Criar');
    if (title == null || !context.mounted) return;
    String? id;
    final ok = await guard(
      context,
      () async => id = await ref
          .read(repoProvider)
          .saveEscala(EscalaDiaconal(id: '', date: ymd(d), title: title.isEmpty ? 'Culto' : title)),
    );
    if (ok && context.mounted) context.go('/mais/escala/$id');
  }

  void _share(BuildContext context, WidgetRef ref) {
    final today = ymd(ref.read(todayProvider));
    final list = [
      for (final e in ref.read(escalasProvider).value ?? const <EscalaDiaconal>[])
        if (e.published && e.date.compareTo(today) >= 0) e,
    ].take(8);
    shareText(context, escalaText(list));
  }
}

/// Escala em texto para o grupo do WhatsApp.
String escalaText(Iterable<EscalaDiaconal> list) {
  final b = StringBuffer('*Escala diaconal*\n');
  for (final e in list) {
    b.write('\n*${capitalize(fmtShortDate(e.date))}${e.time == null ? '' : ' · ${e.time}'} · ${e.title}*\n');
    for (final f in FuncaoDiaconal.values) {
      final ids = e.assignments[f] ?? const [];
      if (ids.isEmpty) continue;
      b.write('${f.label}: ${ids.map((i) => e.names[i] ?? '?').join(', ')}\n');
    }
  }
  return b.toString().trim();
}

class _EscalaRow extends ConsumerWidget {
  const _EscalaRow(this.e, {this.memberId});
  final EscalaDiaconal e;

  /// Quando informado, mostra a função e a resposta desta pessoa.
  final String? memberId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    final recusas = e.people.where((p) => e.confirmations[p]?.status == Resposta.recusado).length;
    final confirmados = e.people.where((p) => e.confirmations[p]?.status == Resposta.confirmado).length;
    final f = memberId == null ? null : e.funcaoOf(memberId!);
    final resp = memberId == null ? null : e.confirmations[memberId!];
    return ListRow(
      leading: f != null
          ? IconTile(f.icon, color: f.color(pal))
          : SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(
                    weekdayShort[DateTime.parse(e.date).weekday - 1].toUpperCase(),
                    style: trackedLabel(pal.accent, size: 10),
                  ),
                  Text(
                    e.date.substring(8),
                    style: TextStyle(
                      fontFamily: brandFont,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: pal.label,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
      title: f != null ? '${capitalize(fmtShortDate(e.date))} · ${e.title}' : e.title,
      subtitle: f != null
          ? '${f.label} · ${resp?.status.label ?? 'confirme'}'
          : [
              if (e.time != null) e.time!,
              '${e.people.length} escalados',
              if (confirmados > 0) '$confirmados confirmados',
            ].join(' · '),
      trailing: !e.published
          ? Pill('Rascunho', color: pal.orange)
          : recusas > 0 && memberId == null
          ? Pill('$recusas recusa${recusas > 1 ? 's' : ''}', color: pal.red)
          : null,
      onTap: () => context.go('/mais/escala/${e.id}'),
    );
  }
}

/// Datas em que o diácono avisa que não pode servir (como os "bloqueios" dos
/// sistemas de escala): a geração automática não o escala nesses dias.
class _Indisponivel extends ConsumerWidget {
  const _Indisponivel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value!;
    final today = ymd(ref.watch(todayProvider));
    final dates = [
      for (final d in user.unavailable)
        if (d.compareTo(today) >= 0) d,
    ];
    return Section(
      header: 'Não posso servir em',
      footer: 'Avise com antecedência: a escala automática não vai te escalar nessas datas.',
      trailing: NavAction(
        label: 'Adicionar',
        onPressed: () async {
          final d = await pickDate(context, first: dateOnly(DateTime.now()));
          if (d == null || !context.mounted) return;
          await guard(context, () => ref.read(repoProvider).setUnavailable(user.uid, [...dates, ymd(d)]));
        },
      ),
      children: [
        for (final d in dates)
          ListRow(
            title: capitalize(fmtLongDate(d)),
            trailing: Tappable(
              onTap: () => ref.read(repoProvider).setUnavailable(user.uid, [...dates.where((x) => x != d)]),
              child: Icon(CupertinoIcons.minus_circle_fill, color: context.pal.red, size: 22),
            ),
          ),
        if (dates.isEmpty) const ListRow(title: 'Nenhuma data'),
      ],
    );
  }
}
