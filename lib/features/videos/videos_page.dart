import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/format.dart';
import '../../core/links.dart';
import '../../core/pickers.dart';
import '../../core/widgets.dart';
import '../../data/models/conteudo.dart';
import '../../data/providers.dart';
import '../common.dart';

/// Vídeos do canal da igreja: os da semana em destaque e o arquivo por data.
class VideosPage extends ConsumerStatefulWidget {
  const VideosPage({super.key});

  @override
  ConsumerState<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends ConsumerState<VideosPage> {
  VideoTipo? _tipo;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final manage = ref.watch(roleProvider).canPublish;
    final igreja = ref.watch(igrejaProvider).value;
    final semana = ref.watch(weekVideosProvider);
    return AppScaffold(
      title: 'Vídeos',
      previousPageTitle: 'Mais',
      actions: [
        if (igreja?.youtube != null)
          NavAction(
            icon: CupertinoIcons.play_rectangle,
            tooltip: 'Canal no YouTube',
            onPressed: () => openUrl(context, igreja!.youtube!),
          ),
        if (manage)
          NavAction(icon: CupertinoIcons.add, tooltip: 'Adicionar vídeo', onPressed: () => editVideo(context, ref)),
      ],
      slivers: [
        if (semana.isNotEmpty)
          SliverToBoxAdapter(
            child: Section(
              header: 'Da semana',
              plain: true,
              children: [
                LayoutBuilder(
                  builder: (context, box) => Wrap(
                    spacing: 14,
                    runSpacing: 18,
                    children: [
                      for (final v in semana)
                        _Editable(
                          video: v,
                          manage: manage,
                          child: VideoCard(v, width: box.maxWidth >= 600 ? (box.maxWidth - 14) / 2 : box.maxWidth),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: SearchField(
              placeholder: 'Título, pregador, texto bíblico',
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ChipBar<VideoTipo?>(
            items: {null: 'Todos', for (final t in VideoTipo.values) t: t.label},
            selected: _tipo,
            onSelected: (v) => setState(() => _tipo = v),
          ),
        ),
        SliverToBoxAdapter(
          child: AsyncView(
            ref.watch(videosProvider),
            builder: (all) {
              final list = [
                for (final v in all)
                  if ((_tipo == null || v.tipo == _tipo) &&
                      (_q.isEmpty || fold('${v.title} ${v.speaker ?? ''} ${v.bibleText ?? ''}').contains(fold(_q))))
                    v,
              ];
              if (all.isEmpty) {
                return EmptyState(
                  icon: CupertinoIcons.play_rectangle,
                  title: 'Nenhum vídeo ainda',
                  message: manage ? 'Cole o link do culto ou estudo publicado no YouTube.' : null,
                );
              }
              return Section(
                header: 'Todos',
                children: [
                  for (final v in list)
                    ListRow(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 72,
                          height: 40,
                          child: v.thumb == null
                              ? const ColoredBox(color: Brand.navy)
                              : Image.network(
                                  v.thumb!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const ColoredBox(color: Brand.navy),
                                ),
                        ),
                      ),
                      title: v.title,
                      subtitle: [fmtDate(v.date), v.tipo.label, ?v.speaker, ?v.bibleText].join(' · '),
                      onTap: () => showVideo(context, v),
                      onLongPress: manage ? () => editVideo(context, ref, v) : null,
                    ),
                  if (list.isEmpty) const ListRow(title: 'Nada encontrado'),
                ],
              );
            },
          ),
        ),
        if (manage)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(32, 12, 32, 0),
              child: Text('Segure um vídeo para editar ou remover.', textAlign: TextAlign.center),
            ),
          ),
      ],
    );
  }
}

class _Editable extends ConsumerWidget {
  const _Editable({required this.video, required this.manage, required this.child});
  final Video video;
  final bool manage;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      GestureDetector(onLongPress: manage ? () => editVideo(context, ref, video) : null, child: child);
}

/// Cadastra/edita um vídeo. Preenche o título pelo próprio YouTube quando possível.
Future<void> editVideo(BuildContext context, WidgetRef ref, [Video? v]) async {
  final url = TextEditingController(text: v?.url);
  final title = TextEditingController(text: v?.title);
  final speaker = TextEditingController(text: v?.speaker);
  final bible = TextEditingController(text: v?.bibleText);
  var date = v?.date ?? ymd(DateTime.now());
  var tipo = v?.tipo ?? VideoTipo.culto;
  final r = await showSheet<String>(
    context,
    tall: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Column(
        children: [
          SheetHeader(
            title: v == null ? 'Novo vídeo' : 'Vídeo',
            action: 'Salvar',
            onAction: () => Navigator.pop(c, 'salvar'),
          ),
          Expanded(
            child: ListView(
              children: [
                Section(
                  footer: 'Cole o link do YouTube (vídeo ou transmissão).',
                  children: [
                    FieldRow(
                      controller: url,
                      placeholder: 'https://youtube.com/watch?v=…',
                      keyboardType: TextInputType.url,
                      autofocus: v == null,
                      onSubmitted: (u) async {
                        if (title.text.trim().isNotEmpty) return;
                        final t = await youtubeTitle(u);
                        if (t != null) setS(() => title.text = t);
                      },
                    ),
                    ListRow(
                      title: 'Buscar título no YouTube',
                      accent: true,
                      onTap: () async {
                        final t = await youtubeTitle(url.text);
                        if (t != null) {
                          setS(() => title.text = t);
                        } else if (c.mounted) {
                          toast(c, 'Não consegui ler o título. Digite abaixo.');
                        }
                      },
                    ),
                  ],
                ),
                Section(
                  children: [
                    FieldRow(controller: title, placeholder: 'Título', maxLines: 2),
                    ChoiceRow<VideoTipo>(
                      label: 'Tipo',
                      value: tipo,
                      options: {for (final t in VideoTipo.values) t: t.label},
                      onChanged: (x) => setS(() => tipo = x ?? tipo),
                    ),
                    DateRow(
                      label: 'Data',
                      value: date,
                      clearable: false,
                      onChanged: (x) => setS(() => date = x ?? date),
                    ),
                    FieldRow(controller: speaker, label: 'Pregador', placeholder: 'Opcional'),
                    FieldRow(controller: bible, label: 'Texto', placeholder: 'Ex.: Atos 13.1-12'),
                  ],
                ),
                if (v != null)
                  Section(
                    children: [
                      ListRow(title: 'Remover vídeo', destructive: true, onTap: () => Navigator.pop(c, 'excluir')),
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
      await guard(context, () => repo.deleteVideo(v!.id), success: 'Removido');
    } else if (youtubeVideoId(url.text) == null) {
      toast(context, 'Link do YouTube inválido.');
    } else {
      String? n(TextEditingController x) => x.text.trim().isEmpty ? null : x.text.trim();
      await guard(
        context,
        () => repo.saveVideo(
          Video(
            id: v?.id ?? '',
            url: url.text,
            title: n(title) ?? 'Vídeo de ${fmtDate(date)}',
            date: date,
            tipo: tipo,
            speaker: n(speaker),
            bibleText: n(bible),
          ),
        ),
        success: 'Vídeo salvo',
      );
    }
  }
  for (final x in [url, title, speaker, bible]) {
    x.dispose();
  }
}

/// Título pelo oEmbed público do YouTube (sem chave). Null se não der.
Future<String?> youtubeTitle(String url) async {
  if (youtubeVideoId(url) == null) return null;
  try {
    final r = await http
        .get(Uri.https('www.youtube.com', '/oembed', {'url': normalizeUrl(url), 'format': 'json'}))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) return null;
    return (jsonDecode(r.body) as Map<String, dynamic>)['title'] as String?;
  } catch (_) {
    return null;
  }
}
