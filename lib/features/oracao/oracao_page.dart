import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models/conteudo.dart';
import '../../data/providers.dart';

/// Pedidos de oração: públicos para a igreja ou reservados ao pastor e conselho.
class OracaoPage extends ConsumerStatefulWidget {
  const OracaoPage({super.key});

  @override
  ConsumerState<OracaoPage> createState() => _OracaoPageState();
}

class _OracaoPageState extends ConsumerState<OracaoPage> {
  bool _respondidos = false;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(roleProvider);
    final uid = ref.watch(uidProvider);
    return AppScaffold(
      title: 'Oração',
      previousPageTitle: 'Mais',
      actions: [NavAction(icon: CupertinoIcons.add, tooltip: 'Novo pedido', onPressed: _novo)],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              '“Confessai, pois, os vossos pecados uns aos outros e orai uns pelos outros.”  Tg 5.16',
              style: context.text.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Segmented(
              value: _respondidos,
              segments: const {false: 'Pedidos', true: 'Respondidos'},
              onChanged: (v) => setState(() => _respondidos = v),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: AsyncView(
            ref.watch(prayersProvider),
            builder: (all) {
              final list = [
                for (final p in all)
                  if (p.answered == _respondidos) p,
              ];
              if (list.isEmpty) {
                return EmptyState(
                  icon: CupertinoIcons.heart_circle,
                  title: _respondidos ? 'Nenhum testemunho ainda' : 'Nenhum pedido',
                  action: _respondidos
                      ? null
                      : TintButton(label: 'Fazer um pedido', icon: CupertinoIcons.add, onPressed: _novo),
                );
              }
              return Column(
                children: [
                  for (final p in list)
                    _PedidoCard(p, uid: uid ?? '', seesNames: role.seesPrivatePrayers, canModerate: role.isLeader),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _novo() async {
    final text = TextEditingController();
    var anonymous = false, private = false;
    final r = await showSheet<bool>(
      context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(title: 'Pedido de oração', action: 'Enviar', onAction: () => Navigator.pop(c, true)),
              Section(
                children: [
                  FieldRow(
                    controller: text,
                    placeholder: 'Pelo que a igreja pode orar?',
                    maxLines: 6,
                    minLines: 3,
                    autofocus: true,
                    capitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
              Section(
                footer: private
                    ? 'Só o pastor e o conselho vão ler. O pastor recebe um aviso.'
                    : 'Toda a igreja verá o pedido e poderá marcar que está orando.',
                children: [
                  ListRow(
                    title: 'Reservado ao pastor',
                    trailing: AppSwitch(value: private, onChanged: (v) => setS(() => private = v)),
                  ),
                  if (!private)
                    ListRow(
                      title: 'Sem mostrar meu nome',
                      trailing: AppSwitch(value: anonymous, onChanged: (v) => setS(() => anonymous = v)),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
    final t = text.text.trim();
    text.dispose();
    if (r != true || t.isEmpty || !mounted) return;
    final user = ref.read(currentUserProvider).value!;
    final member = ref.read(myMemberProvider).value;
    await guard(
      context,
      () => ref
          .read(repoProvider)
          .addPrayer(
            uid: user.uid,
            name: member?.name ?? user.name,
            text: t,
            anonymous: anonymous && !private,
            private: private,
          ),
      success: 'Pedido enviado',
    );
  }
}

class _PedidoCard extends ConsumerWidget {
  const _PedidoCard(this.p, {required this.uid, required this.seesNames, required this.canModerate});
  final PedidoOracao p;
  final String uid;
  final bool seesNames;
  final bool canModerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    final orando = p.praying.contains(uid);
    final mine = p.authorUid == uid;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(p.displayName(seesNames || mine), style: context.text.titleSmall)),
                if (p.private) Pill('Reservado', color: pal.purple, icon: CupertinoIcons.lock_fill),
              ],
            ),
            const SizedBox(height: 6),
            Text(p.text, style: context.text.bodyLarge),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.createdAt.isEmpty ? '' : fmtDateTime(p.createdAt),
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall,
                  ),
                ),
                if (mine || canModerate)
                  NavAction(
                    icon: CupertinoIcons.ellipsis_circle,
                    onPressed: () async {
                      final a = await showActionSheet<String>(
                        context,
                        actions: [
                          SheetAction(
                            p.answered ? 'Voltar para pedidos' : 'Deus respondeu!',
                            'resp',
                            icon: CupertinoIcons.sparkles,
                          ),
                          const SheetAction('Excluir', 'del', destructive: true),
                        ],
                      );
                      if (a == null || !context.mounted) return;
                      final repo = ref.read(repoProvider);
                      await guard(
                        context,
                        () => a == 'resp' ? repo.setAnswered(p.id, !p.answered) : repo.deletePrayer(p.id),
                      );
                    },
                  ),
                const SizedBox(width: 10),
                if (!p.private)
                  TintButton(
                    label: '${orando ? 'Orando' : 'Vou orar'}${p.praying.isEmpty ? '' : ' · ${p.praying.length}'}',
                    icon: orando ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    color: orando ? pal.pink : pal.accent,
                    onPressed: () => ref.read(repoProvider).togglePraying(p, uid),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
