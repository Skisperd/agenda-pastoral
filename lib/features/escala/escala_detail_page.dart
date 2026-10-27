import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/pickers.dart';
import '../../core/roles.dart';
import '../../core/share.dart';
import '../../core/widgets.dart';
import '../../data/models/escala.dart';
import '../../data/models/people.dart';
import '../../data/providers.dart';
import '../../domain/escala_generator.dart';
import 'escala_page.dart';

class EscalaDetailPage extends ConsumerWidget {
  const EscalaDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(escalaProvider(id));
    final role = ref.watch(roleProvider);
    final manage = role.canManageEscala;
    final me = ref.watch(currentUserProvider).value;
    final pal = context.pal;
    if (e == null) {
      return AppScaffold(
        title: 'Escala',
        large: false,
        slivers: [
          SliverToBoxAdapter(
            child: ref.watch(escalasProvider).isLoading
                ? const SizedBox.shrink()
                : const EmptyState(icon: CupertinoIcons.person_3, title: 'Escala não encontrada'),
          ),
        ],
      );
    }
    final myFuncao = me?.memberId == null ? null : e.funcaoOf(me!.memberId!);
    final myResp = me?.memberId == null ? null : e.confirmations[me!.memberId!];

    return AppScaffold(
      title: capitalize(fmtShortDate(e.date)),
      large: false,
      previousPageTitle: 'Escala',
      maxWidth: kFormWidth,
      actions: [
        NavAction(
          icon: CupertinoIcons.square_arrow_up,
          tooltip: 'Compartilhar',
          onPressed: () => shareText(context, escalaText([e])),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title, style: context.text.headlineSmall),
                Text(
                  [capitalize(fmtLongDate(e.date)), if (e.time != null) 'às ${e.time}'].join(' '),
                  style: context.text.bodyMedium,
                ),
                if (!e.published) ...[
                  const SizedBox(height: 8),
                  Pill('Rascunho · só a coordenação vê', color: pal.orange),
                ],
              ],
            ),
          ),
        ),
        if (myFuncao != null)
          SliverToBoxAdapter(
            child: Section(
              header: 'Você está escalado',
              children: [
                ListRow(
                  leading: IconTile(myFuncao.icon, color: myFuncao.color(pal)),
                  title: myFuncao.label,
                  subtitle: myResp == null
                      ? 'Confirme sua presença'
                      : '${myResp.status.label}${myResp.note == null ? '' : ' · ${myResp.note}'}',
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TintButton(
                          label: 'Confirmo',
                          icon: CupertinoIcons.checkmark_alt,
                          color: pal.green,
                          expand: true,
                          onPressed: myResp?.status == Resposta.confirmado
                              ? null
                              : () => guard(
                                  context,
                                  () => ref.read(repoProvider).respondEscala(e.id, me!.memberId!, Resposta.confirmado),
                                  success: 'Presença confirmada',
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TintButton(
                          label: 'Não posso',
                          icon: CupertinoIcons.xmark,
                          color: pal.red,
                          expand: true,
                          onPressed: myResp?.status == Resposta.recusado
                              ? null
                              : () async {
                                  final note = await promptText(
                                    context,
                                    title: 'Não vai poder?',
                                    message: 'A coordenação será avisada para escalar um substituto.',
                                    placeholder: 'Motivo (opcional)',
                                    ok: 'Avisar',
                                  );
                                  if (note == null || !context.mounted) return;
                                  await guard(
                                    context,
                                    () => ref
                                        .read(repoProvider)
                                        .respondEscala(
                                          e.id,
                                          me!.memberId!,
                                          Resposta.recusado,
                                          note: note.isEmpty ? null : note,
                                        ),
                                    success: 'Coordenação avisada',
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        for (final f in FuncaoDiaconal.values)
          if ((e.assignments[f] ?? const []).isNotEmpty || manage)
            SliverToBoxAdapter(
              child: Section(
                header: f.label,
                trailing: manage ? NavAction(label: 'Escalar', onPressed: () => _add(context, ref, e, f)) : null,
                children: [
                  for (final id in e.assignments[f] ?? const <String>[])
                    _PessoaRow(e: e, funcao: f, memberId: id, manage: manage),
                  if ((e.assignments[f] ?? const []).isEmpty) const ListRow(title: 'Ninguém'),
                ],
              ),
            ),
        if (manage)
          SliverToBoxAdapter(
            child: Section(
              header: 'Coordenação',
              children: [
                ListRow(
                  title: 'Publicada',
                  subtitle: e.published ? 'Os diáconos veem e confirmam' : 'Rascunho',
                  trailing: AppSwitch(
                    value: e.published,
                    onChanged: (v) => guard(context, () => ref.read(repoProvider).saveEscala(e.copyWith(published: v))),
                  ),
                ),
                ListRow(
                  title: 'Culto',
                  value: e.title,
                  onTap: () async {
                    final t = await promptText(context, title: 'Nome do culto', placeholder: e.title);
                    if (t == null || t.isEmpty || !context.mounted) return;
                    await guard(context, () => ref.read(repoProvider).saveEscala(e.copyWith(title: t)));
                  },
                ),
                TimeRow(
                  label: 'Horário',
                  value: e.time,
                  onChanged: (v) => guard(context, () => ref.read(repoProvider).saveEscala(e.copyWith(time: v))),
                ),
                ListRow(
                  title: 'Excluir escala',
                  destructive: true,
                  onTap: () async {
                    if (!await confirm(context, 'Excluir esta escala?', ok: 'Excluir', destructive: true)) return;
                    if (!context.mounted) return;
                    final ok = await guard(context, () => ref.read(repoProvider).deleteEscala(e.id));
                    if (ok && context.mounted) context.go('/mais/escala');
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Escolher alguém para a função, com os mais indicados primeiro.
  Future<void> _add(BuildContext context, WidgetRef ref, EscalaDiaconal e, FuncaoDiaconal f) async {
    final cands = candidatos(ref);
    final ranked = const EscalaGenerator().sugerir(
      data: e.date,
      funcao: f,
      candidatos: cands,
      ocupados: e.people,
      carga: cargaRecente(ref),
    );
    final picked = await showActionSheet<Candidato>(
      context,
      title: f.label,
      message: ranked.isEmpty ? 'Ninguém disponível nesta data.' : 'Em ordem: quem serviu menos e está livre.',
      actions: [for (final c in ranked.take(10)) SheetAction(c.name, c)],
    );
    if (picked == null || !context.mounted) return;
    await _assign(context, ref, e, f, [...?e.assignments[f], picked.id], {picked.id: picked.name});
  }
}

Future<void> _assign(
  BuildContext context,
  WidgetRef ref,
  EscalaDiaconal e,
  FuncaoDiaconal f,
  List<String> ids, [
  Map<String, String> newNames = const {},
]) {
  final assignments = {...e.assignments, f: ids};
  final names = {...e.names, ...newNames};
  return guard(context, () => ref.read(repoProvider).saveEscala(e.copyWith(assignments: assignments, names: names)));
}

/// Quem pode ser escalado, com as datas em que não pode.
List<Candidato> candidatos(WidgetRef ref) {
  final unav = ref.read(unavailableByMemberProvider);
  return [
    for (final m in ref.read(diaconiaMembersProvider).value ?? const <Membro>[])
      Candidato(id: m.id, name: m.name, funcoes: m.funcoes, unavailable: unav[m.id] ?? const {}),
  ];
}

/// Quantas vezes cada um serviu nos últimos 60 dias (para equilibrar).
Map<String, int> cargaRecente(WidgetRef ref) {
  final since = ymd(addDays(DateTime.now(), -60));
  final out = <String, int>{};
  for (final e in ref.read(escalasProvider).value ?? const <EscalaDiaconal>[]) {
    if (e.date.compareTo(since) < 0) continue;
    for (final p in e.people) {
      out[p] = (out[p] ?? 0) + 1;
    }
  }
  return out;
}

class _PessoaRow extends ConsumerWidget {
  const _PessoaRow({required this.e, required this.funcao, required this.memberId, required this.manage});
  final EscalaDiaconal e;
  final FuncaoDiaconal funcao;
  final String memberId;
  final bool manage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    final c = e.confirmations[memberId];
    final name = e.names[memberId] ?? ref.watch(memberMapProvider)[memberId]?.name ?? '?';
    final phone = ref.watch(memberMapProvider)[memberId]?.phone;
    return ListRow(
      leading: Initials(name, size: 32),
      title: name,
      subtitle: c?.note,
      trailing: Pill(
        c?.status.label ?? 'Aguardando',
        color: switch (c?.status) {
          Resposta.confirmado => pal.green,
          Resposta.recusado => pal.red,
          null => pal.gray,
        },
      ),
      onTap: !manage
          ? null
          : () async {
              final a = await showActionSheet<String>(
                context,
                title: name,
                actions: [
                  if (c?.status == Resposta.recusado)
                    const SheetAction('Trocar por substituto', 'sub', icon: CupertinoIcons.arrow_2_squarepath),
                  if (phone != null) const SheetAction('WhatsApp', 'whats', icon: CupertinoIcons.chat_bubble_text),
                  const SheetAction('Tirar da escala', 'tirar', destructive: true),
                ],
              );
              if (a == null || !context.mounted) return;
              final rest = [...?e.assignments[funcao]]..remove(memberId);
              switch (a) {
                case 'whats':
                  await openWhatsApp(
                    context,
                    phone!,
                    text:
                        'Olá, ${name.split(' ').first}! Você está na escala diaconal de '
                        '${fmtShortDate(e.date)} (${e.title}) em ${funcao.label}. Pode confirmar pelo app?',
                  );
                case 'tirar':
                  await _assign(context, ref, e, funcao, rest);
                case 'sub':
                  final ranked = const EscalaGenerator().sugerir(
                    data: e.date,
                    funcao: funcao,
                    candidatos: candidatos(ref),
                    ocupados: e.people,
                    carga: cargaRecente(ref),
                  );
                  if (ranked.isEmpty) {
                    toast(context, 'Ninguém disponível para substituir.');
                    return;
                  }
                  final s = await showActionSheet<Candidato>(
                    context,
                    title: 'Substituto para $name',
                    message: 'Sugestões: livres nesta data e que serviram menos.',
                    actions: [for (final c in ranked.take(8)) SheetAction(c.name, c)],
                  );
                  if (s == null || !context.mounted) return;
                  await _assign(context, ref, e, funcao, [...rest, s.id], {s.id: s.name});
              }
            },
    );
  }
}
