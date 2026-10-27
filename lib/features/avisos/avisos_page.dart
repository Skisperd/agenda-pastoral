import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/links.dart';
import '../../core/pickers.dart';
import '../../core/share.dart';
import '../../core/widgets.dart';
import '../../data/models/conteudo.dart';
import '../../data/providers.dart';

/// Mural de avisos da igreja.
class AvisosPage extends ConsumerWidget {
  const AvisosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manage = ref.watch(roleProvider).canPublish;
    final today = ymd(ref.watch(todayProvider));
    return AppScaffold(
      title: 'Avisos',
      previousPageTitle: 'Mais',
      actions: [
        if (manage) NavAction(icon: CupertinoIcons.add, tooltip: 'Novo aviso', onPressed: () => _edit(context, ref)),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: AsyncView(
            ref.watch(avisosProvider),
            builder: (all) {
              final visible = [
                for (final a in all)
                  if (manage || a.visibleOn(today)) a,
              ]..sort((a, b) => a.pinned != b.pinned ? (a.pinned ? -1 : 1) : b.createdAt.compareTo(a.createdAt));
              if (visible.isEmpty) return const EmptyState(icon: CupertinoIcons.news, title: 'Nenhum aviso');
              return Column(
                children: [
                  for (final a in visible)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Tappable(
                        onTap: manage ? () => _edit(context, ref, a) : null,
                        pressedOpacity: .8,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: context.pal.card, borderRadius: BorderRadius.circular(14)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (a.pinned) ...[
                                    Icon(CupertinoIcons.pin_fill, size: 15, color: context.pal.orange),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(child: Text(a.title, style: context.text.titleMedium)),
                                  if (!a.visibleOn(today)) Pill('Expirado', color: context.pal.gray),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(a.body, style: context.text.bodyLarge),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      [?a.author, if (a.createdAt.isNotEmpty) fmtDateTime(a.createdAt)].join(' · '),
                                      style: context.text.bodySmall,
                                    ),
                                  ),
                                  if (a.link != null) LinkButton(label: 'Abrir', url: a.link!),
                                  const SizedBox(width: 8),
                                  TintButton(
                                    label: 'Enviar',
                                    icon: CupertinoIcons.share,
                                    onPressed: () => shareText(
                                      context,
                                      '*${a.title}*\n${a.body}${a.link == null ? '' : '\n${a.link}'}',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, [Aviso? a]) async {
    final title = TextEditingController(text: a?.title);
    final body = TextEditingController(text: a?.body);
    final link = TextEditingController(text: a?.link);
    final author = TextEditingController(text: a?.author ?? ref.read(currentUserProvider).value?.name);
    var pinned = a?.pinned ?? false;
    String? until = a?.until;
    final r = await showSheet<String>(
      context,
      tall: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Column(
          children: [
            SheetHeader(
              title: a == null ? 'Novo aviso' : 'Aviso',
              action: 'Salvar',
              onAction: () => Navigator.pop(c, 'salvar'),
            ),
            Expanded(
              child: ListView(
                children: [
                  Section(
                    children: [
                      FieldRow(
                        controller: title,
                        placeholder: 'Título',
                        autofocus: a == null,
                        capitalization: TextCapitalization.sentences,
                      ),
                      FieldRow(
                        controller: body,
                        placeholder: 'Texto do aviso',
                        maxLines: 8,
                        minLines: 3,
                        capitalization: TextCapitalization.sentences,
                      ),
                      FieldRow(
                        controller: link,
                        label: 'Link',
                        placeholder: 'Opcional',
                        keyboardType: TextInputType.url,
                      ),
                      FieldRow(controller: author, label: 'Assinado', placeholder: 'Conselho, secretaria…'),
                    ],
                  ),
                  Section(
                    children: [
                      ListRow(
                        title: 'Fixar no Início',
                        trailing: AppSwitch(value: pinned, onChanged: (v) => setS(() => pinned = v)),
                      ),
                      DateRow(label: 'Mostrar até', value: until, onChanged: (v) => setS(() => until = v)),
                    ],
                  ),
                  if (a != null)
                    Section(
                      children: [
                        ListRow(title: 'Excluir aviso', destructive: true, onTap: () => Navigator.pop(c, 'excluir')),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (r != null && context.mounted) {
      final repo = ref.read(repoProvider);
      if (r == 'excluir') {
        await guard(context, () => repo.deleteAviso(a!.id));
      } else if (title.text.trim().isNotEmpty) {
        if (!isValidUrl(link.text)) {
          toast(context, 'Link inválido.');
        } else {
          await guard(
            context,
            () => repo.saveAviso(
              Aviso(
                id: a?.id ?? '',
                title: title.text,
                body: body.text,
                createdAt: a?.createdAt ?? '',
                author: author.text.trim().isEmpty ? null : author.text.trim(),
                pinned: pinned,
                until: until,
                link: link.text.trim().isEmpty ? null : link.text.trim(),
              ),
            ),
            success: 'Aviso publicado',
          );
        }
      }
    }
    for (final x in [title, body, link, author]) {
      x.dispose();
    }
  }
}
