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
import '../../data/models/igreja.dart';
import '../../data/providers.dart';
import '../../data/store/doc_store.dart' show nowIso;
import '../common.dart';

enum _Aba { detalhes, inscricoes, tarefas, orcamento }

class EventoDetailPage extends ConsumerStatefulWidget {
  const EventoDetailPage({super.key, required this.id});
  final String id;

  @override
  ConsumerState<EventoDetailPage> createState() => _EventoDetailPageState();
}

class _EventoDetailPageState extends ConsumerState<EventoDetailPage> {
  _Aba _aba = _Aba.detalhes;

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(eventProvider(widget.id));
    final manage = ref.watch(roleProvider).canManageEvents;
    if (e == null) {
      return AppScaffold(
        title: 'Evento',
        large: false,
        slivers: [
          SliverToBoxAdapter(
            child: ref.watch(eventsProvider).isLoading
                ? const SizedBox.shrink()
                : const EmptyState(icon: CupertinoIcons.star, title: 'Evento não encontrado'),
          ),
        ],
      );
    }
    final aba = manage ? _aba : _Aba.detalhes;
    return AppScaffold(
      title: e.title,
      large: false,
      previousPageTitle: 'Agenda',
      maxWidth: kFormWidth,
      actions: [
        NavAction(icon: CupertinoIcons.square_arrow_up, tooltip: 'Compartilhar', onPressed: () => _share(e)),
        if (manage) NavAction(label: 'Editar', onPressed: () => context.go('/agenda/evento/${e.id}/editar')),
      ],
      slivers: [
        SliverToBoxAdapter(child: _Header(e)),
        if (manage)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Segmented(
                value: aba,
                segments: const {
                  _Aba.detalhes: 'Detalhes',
                  _Aba.inscricoes: 'Inscritos',
                  _Aba.tarefas: 'Tarefas',
                  _Aba.orcamento: 'Orçamento',
                },
                onChanged: (v) => setState(() => _aba = v),
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: switch (aba) {
            _Aba.detalhes => _Detalhes(e),
            _Aba.inscricoes => _Inscricoes(e),
            _Aba.tarefas => _Tarefas(e),
            _Aba.orcamento => _Orcamento(e),
          },
        ),
      ],
    );
  }

  void _share(Evento e) {
    final b = StringBuffer('*${e.title}*\n')..write('📅 ${capitalize(fmtLongDate(e.day))} às ${fmtHour(e.start)}\n');
    if (e.place != null) b.write('📍 ${e.place}${e.address == null ? '' : ' · ${e.address}'}\n');
    if (e.price != null) b.write('💲 ${e.price}\n');
    if (e.description != null) b.write('\n${e.description}\n');
    if (e.registration) b.write('\nInscrições pelo app da igreja.');
    shareText(context, b.toString().trim());
  }
}

class _Header extends StatelessWidget {
  const _Header(this.e);
  final Evento e;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final fim = e.end == null
        ? null
        : ymd(e.end!) == e.day
        ? 'até ${fmtHour(e.end!)}'
        : 'até ${fmtShortDate(ymd(e.end!))}, ${fmtHour(e.end!)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: Brand.heroGradient, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(e.categoria.icon, color: Brand.gold, size: 16),
                const SizedBox(width: 6),
                Text(e.categoria.label.toUpperCase(), style: trackedLabel(Colors.white.withValues(alpha: .75))),
                const Spacer(),
                if (!e.published) Pill('Rascunho', color: pal.orange, solid: true),
                if (e.status == EventoStatus.cancelado) Pill('Cancelado', color: pal.red, solid: true),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              e.title,
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, height: 1.15),
            ),
            const SizedBox(height: 8),
            Text(
              '${capitalize(fmtLongDate(e.day))} · ${fmtHour(e.start)}${fim == null ? '' : ' $fim'}',
              style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 15),
            ),
            if (e.place != null)
              Text(e.place!, style: TextStyle(color: Colors.white.withValues(alpha: .75), fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class _Detalhes extends ConsumerWidget {
  const _Detalhes(this.e);
  final Evento e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final mine = ref.watch(myRegistrationProvider(e.id)).value;
    final regs = ref.watch(registrationsProvider(e.id)).value;
    final (ok, wait) = regs == null ? (const <Inscricao>[], const <Inscricao>[]) : splitWaitlist(regs, e.capacity);
    final used = ok.fold<int>(0, (a, i) => a + i.people);
    final naEspera = mine != null && wait.any((w) => w.uid == mine.uid);
    return Column(
      children: [
        if (e.description != null)
          Section(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(e.description!, style: context.text.bodyLarge),
              ),
            ],
          ),
        Section(
          children: [
            if (e.responsible != null) ListRow(title: 'Responsável', value: e.responsible),
            if (e.price != null) ListRow(title: 'Valor', value: e.price),
            if (e.address != null)
              ListRow(
                title: 'Como chegar',
                subtitle: e.address,
                trailing: Icon(CupertinoIcons.map_fill, color: context.pal.accent, size: 20),
                onTap: () => openUrl(
                  context,
                  Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': e.address}).toString(),
                ),
              ),
            if (e.link != null)
              ListRow(title: 'Link do evento', subtitle: e.link, onTap: () => openUrl(context, e.link!)),
            if (e.registration && e.capacity != null)
              ListRow(title: 'Vagas', value: '${(e.capacity! - used).clamp(0, e.capacity!)} de ${e.capacity}'),
            if (e.registration && e.deadline != null) ListRow(title: 'Inscrições até', value: fmtDate(e.deadline!)),
          ],
        ),
        if (e.registration)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: mine != null
                ? Column(
                    children: [
                      NoticeCard(
                        icon: naEspera ? CupertinoIcons.hourglass : CupertinoIcons.checkmark_seal_fill,
                        title: naEspera ? 'Você está na lista de espera' : 'Você está inscrito',
                        message: mine.guests > 0 ? 'Com ${mine.guests} acompanhante(s)' : null,
                        color: naEspera ? context.pal.orange : context.pal.green,
                      ),
                      const SizedBox(height: 10),
                      TintButton(
                        label: 'Cancelar inscrição',
                        color: context.pal.red,
                        expand: true,
                        large: true,
                        onPressed: () async {
                          if (!await confirm(
                            context,
                            'Cancelar inscrição?',
                            ok: 'Cancelar inscrição',
                            destructive: true,
                          )) {
                            return;
                          }
                          if (context.mounted) {
                            await guard(
                              context,
                              () => ref.read(repoProvider).unregister(e.id, mine.uid),
                              success: 'Inscrição cancelada',
                            );
                          }
                        },
                      ),
                    ],
                  )
                : e.registrationOpen(today)
                ? PrimaryButton(
                    label: e.capacity != null && used >= e.capacity! ? 'Entrar na lista de espera' : 'Quero participar',
                    icon: CupertinoIcons.person_badge_plus,
                    onPressed: () => _inscrever(context, ref),
                  )
                : const Text('Inscrições encerradas.', textAlign: TextAlign.center),
          ),
      ],
    );
  }

  Future<void> _inscrever(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider).value!;
    final member = ref.read(myMemberProvider).value;
    var guests = 0;
    final note = TextEditingController();
    final go = await showAppDialog<bool>(
      context,
      title: 'Inscrição',
      message: e.title,
      content: StatefulBuilder(
        builder: (c, setS) => Column(
          children: [
            Row(
              children: [
                const Expanded(child: Text('Acompanhantes')),
                IconButton(
                  onPressed: guests == 0 ? null : () => setS(() => guests--),
                  icon: const Icon(CupertinoIcons.minus_circle),
                ),
                Text('$guests', style: c.text.titleMedium),
                IconButton(onPressed: () => setS(() => guests++), icon: const Icon(CupertinoIcons.plus_circle)),
              ],
            ),
            CupertinoTextField(
              controller: note,
              placeholder: 'Observação (restrição alimentar, carona…)',
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.pal.background, borderRadius: BorderRadius.circular(9)),
            ),
          ],
        ),
      ),
      actions: const [DialogAction('Cancelar', false), DialogAction('Inscrever', true, primary: true)],
    );
    final text = note.text.trim();
    note.dispose();
    if (go != true || !context.mounted) return;
    await guard(
      context,
      () => ref
          .read(repoProvider)
          .register(
            e.id,
            Inscricao(
              uid: user.uid,
              name: member?.name ?? user.name,
              guests: guests,
              note: text.isEmpty ? null : text,
              createdAt: nowIso(),
            ),
          ),
      success: 'Inscrição feita',
    );
  }
}

class _Inscricoes extends ConsumerWidget {
  const _Inscricoes(this.e);
  final Evento e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      ref.watch(registrationsProvider(e.id)),
      builder: (regs) {
        final (ok, wait) = splitWaitlist(regs, e.capacity);
        final total = ok.fold<int>(0, (a, i) => a + i.people);
        final presentes = ok.where((i) => i.checkedIn).fold<int>(0, (a, i) => a + i.people);
        Widget row(Inscricao i) => ListRow(
          leading: Initials(i.name, size: 32),
          title: i.name,
          subtitle: [if (i.guests > 0) '+${i.guests}', ?i.note].join(' · '),
          trailing: Tappable(
            onTap: () => ref.read(repoProvider).checkIn(e.id, i.uid, !i.checkedIn),
            child: Icon(
              i.checkedIn ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
              color: i.checkedIn ? context.pal.green : context.pal.tertiaryLabel,
              size: 26,
            ),
          ),
        );
        return Column(
          children: [
            Section(
              header: 'Confirmados',
              footer:
                  '$total pessoa(s)${e.capacity == null ? '' : ' de ${e.capacity} vagas'} · $presentes presente(s). '
                  'Toque no círculo para registrar a presença no dia.',
              trailing: NavAction(
                label: 'Copiar lista',
                onPressed: () => copyForWhatsApp(
                  context,
                  '*${e.title} · inscritos*\n${[for (final (n, i) in ok.indexed) '${n + 1}. ${i.name}${i.guests > 0 ? ' (+${i.guests})' : ''}'].join('\n')}',
                ),
              ),
              children: [
                for (final i in ok) row(i),
                if (ok.isEmpty) const ListRow(title: 'Ninguém inscrito ainda'),
              ],
            ),
            if (wait.isNotEmpty)
              Section(
                header: 'Lista de espera',
                footer: 'Quando alguém cancelar, o primeiro da espera entra automaticamente.',
                children: [for (final i in wait) row(i)],
              ),
          ],
        );
      },
    );
  }
}

class _Tarefas extends ConsumerWidget {
  const _Tarefas(this.e);
  final Evento e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ymd(ref.watch(todayProvider));
    return AsyncView(
      ref.watch(tasksProvider(e.id)),
      builder: (tasks) {
        final done = tasks.where((t) => t.done).length;
        return Column(
          children: [
            if (tasks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$done de ${tasks.length} concluídas', style: context.text.bodyMedium),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: tasks.isEmpty ? 0 : done / tasks.length,
                        minHeight: 8,
                        backgroundColor: context.pal.fill,
                        color: context.pal.green,
                      ),
                    ),
                  ],
                ),
              ),
            Section(
              trailing: NavAction(label: 'Nova tarefa', onPressed: () => _edit(context, ref)),
              header: 'Checklist',
              children: [
                for (final t in tasks)
                  ListRow(
                    leading: Tappable(
                      onTap: () => ref
                          .read(repoProvider)
                          .saveTask(
                            e.id,
                            Tarefa(
                              id: t.id,
                              title: t.title,
                              assignee: t.assignee,
                              due: t.due,
                              notes: t.notes,
                              done: !t.done,
                            ),
                          ),
                      child: Icon(
                        t.done ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                        color: t.done ? context.pal.green : context.pal.tertiaryLabel,
                        size: 26,
                      ),
                    ),
                    titleWidget: Text(
                      t.title,
                      style: context.text.bodyLarge?.copyWith(
                        decoration: t.done ? TextDecoration.lineThrough : null,
                        color: t.done ? context.pal.secondaryLabel : null,
                      ),
                    ),
                    subtitle: [?t.assignee, if (t.due != null) 'até ${fmtDate(t.due!).substring(0, 5)}'].join(' · '),
                    trailing: !t.done && t.due != null && t.due!.compareTo(today) < 0
                        ? Pill('Atrasada', color: context.pal.red)
                        : null,
                    onTap: () => _edit(context, ref, t),
                  ),
                if (tasks.isEmpty)
                  const ListRow(title: 'Nenhuma tarefa. Ex.: reservar local, convidar preletor, comprar materiais.'),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, [Tarefa? t]) async {
    final title = TextEditingController(text: t?.title);
    final who = TextEditingController(text: t?.assignee);
    final notes = TextEditingController(text: t?.notes);
    String? due = t?.due;
    final r = await showSheet<String>(
      context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(
                title: t == null ? 'Nova tarefa' : 'Tarefa',
                action: 'Salvar',
                onAction: () => Navigator.pop(c, 'salvar'),
              ),
              Section(
                children: [
                  FieldRow(controller: title, placeholder: 'O que precisa ser feito', autofocus: t == null),
                  FieldRow(controller: who, label: 'Responsável', placeholder: 'Nome'),
                  DateRow(label: 'Prazo', value: due, onChanged: (v) => setS(() => due = v)),
                  FieldRow(controller: notes, placeholder: 'Observações', maxLines: 3),
                ],
              ),
              if (t != null)
                Section(
                  children: [
                    ListRow(title: 'Excluir tarefa', destructive: true, onTap: () => Navigator.pop(c, 'excluir')),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
    if (r == null || !context.mounted) return;
    final repo = ref.read(repoProvider);
    if (r == 'excluir') {
      await guard(context, () => repo.deleteTask(e.id, t!.id));
    } else if (title.text.trim().isNotEmpty) {
      String? n(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
      await guard(
        context,
        () => repo.saveTask(
          e.id,
          Tarefa(
            id: t?.id ?? '',
            title: title.text,
            assignee: n(who),
            due: due,
            notes: n(notes),
            done: t?.done ?? false,
          ),
        ),
      );
    }
    for (final c in [title, who, notes]) {
      c.dispose();
    }
  }
}

class _Orcamento extends ConsumerWidget {
  const _Orcamento(this.e);
  final Evento e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    return AsyncView(
      ref.watch(budgetProvider(e.id)),
      builder: (itens) {
        final o = Orcamento(itens);
        Widget tile(String label, double v, Color c) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: trackedLabel(pal.secondaryLabel, size: 10)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    fmtMoney(v),
                    style: TextStyle(fontFamily: numFont, fontSize: 17, fontWeight: FontWeight.w700, color: c),
                  ),
                ),
              ],
            ),
          ),
        );
        Widget lista(bool receita) => Section(
          header: receita ? 'Entradas' : 'Despesas',
          trailing: NavAction(
            label: 'Adicionar',
            onPressed: () => _edit(context, ref, receita: receita),
          ),
          children: [
            for (final l in itens.where((i) => i.receita == receita))
              ListRow(
                title: l.description,
                subtitle: 'Previsto ${fmtMoney(l.planned)}',
                value: l.actual == null ? 'a ${receita ? 'receber' : 'pagar'}' : fmtMoney(l.actual!),
                onTap: () => _edit(context, ref, item: l, receita: receita),
              ),
            if (!itens.any((i) => i.receita == receita)) const ListRow(title: 'Nada lançado'),
          ],
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  tile('DESPESAS', o.despesaPrevista, pal.red),
                  const SizedBox(width: 8),
                  tile('ENTRADAS', o.receitaPrevista, pal.green),
                  const SizedBox(width: 8),
                  tile('SALDO', o.saldoPrevisto, o.saldoPrevisto < 0 ? pal.red : pal.accent),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Previsto. Realizado até agora: entradas ${fmtMoney(o.receitaRealizada)}, '
                'despesas ${fmtMoney(o.despesaRealizada)}, saldo ${fmtMoney(o.saldoRealizado)}.',
                style: context.text.bodySmall,
              ),
            ),
            lista(false),
            lista(true),
          ],
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, {Lancamento? item, required bool receita}) async {
    final desc = TextEditingController(text: item?.description);
    final planned = TextEditingController(
      text: item == null ? '' : item.planned.toStringAsFixed(2).replaceAll('.', ','),
    );
    final actual = TextEditingController(text: item?.actual?.toStringAsFixed(2).replaceAll('.', ','));
    final r = await showSheet<String>(
      context,
      builder: (c) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(
              title: receita ? 'Entrada' : 'Despesa',
              action: 'Salvar',
              onAction: () => Navigator.pop(c, 'salvar'),
            ),
            Section(
              children: [
                FieldRow(
                  controller: desc,
                  placeholder: receita ? 'Ex.: inscrições, oferta' : 'Ex.: aluguel, alimentação',
                  autofocus: item == null,
                ),
                FieldRow(
                  controller: planned,
                  label: 'Previsto',
                  placeholder: '0,00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                FieldRow(
                  controller: actual,
                  label: 'Realizado',
                  placeholder: 'Ainda não',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ),
            if (item != null)
              Section(
                children: [ListRow(title: 'Excluir', destructive: true, onTap: () => Navigator.pop(c, 'excluir'))],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
    if (r == null || !context.mounted) return;
    final repo = ref.read(repoProvider);
    if (r == 'excluir') {
      await guard(context, () => repo.deleteBudgetItem(e.id, item!.id));
    } else if (desc.text.trim().isNotEmpty) {
      await guard(
        context,
        () => repo.saveBudgetItem(
          e.id,
          Lancamento(
            id: item?.id ?? '',
            description: desc.text,
            receita: receita,
            planned: parseMoney(planned.text) ?? 0,
            actual: parseMoney(actual.text),
          ),
        ),
      );
    }
    for (final c in [desc, planned, actual]) {
      c.dispose();
    }
  }
}
