import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/links.dart';
import '../../core/pickers.dart';
import '../../core/widgets.dart';
import '../../data/models/pg.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';
import '../../data/store/file_store.dart';

/// Orientação de uma pergunta, só para quem conduz o PG. A liderança edita.
class Orientacao extends ConsumerWidget {
  const Orientacao({
    super.key,
    required this.estudoId,
    required this.indice,
    required this.texto,
    this.podeEditar = false,
  });
  final String estudoId;
  final int indice;
  final String texto;
  final bool podeEditar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    return Material(
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 4),
          title: Text(
            texto.isEmpty ? 'Escrever orientação para os líderes' : 'Orientação para quem conduz',
            style: TextStyle(color: pal.accent, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          children: [
            if (texto.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.accent.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(texto, style: context.text.bodyLarge?.copyWith(fontSize: 15, height: 1.45)),
              ),
            if (podeEditar)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TintButton(
                    label: texto.isEmpty ? 'Escrever' : 'Editar orientação',
                    icon: CupertinoIcons.pencil,
                    onPressed: () async {
                      final ctrl = TextEditingController(text: texto);
                      final ok = await showSheet<bool>(
                        context,
                        tall: true,
                        builder: (c) => Column(
                          children: [
                            SheetHeader(
                              title: 'Orientação · pergunta ${indice + 1}',
                              action: 'Salvar',
                              onAction: () => Navigator.pop(c, true),
                            ),
                            Expanded(
                              child: ListView(
                                children: [
                                  Section(
                                    footer: 'Só quem conduz pequeno grupo e a liderança veem.',
                                    children: [FieldRow(controller: ctrl, maxLines: 30, minLines: 10, autofocus: true)],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        await guard(
                          context,
                          () => ref.read(repoProvider).saveGuia(estudoId, indice, ctrl.text.trim()),
                          success: 'Orientação salva',
                        );
                      }
                      ctrl.dispose();
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension TipoMaterialStyle on TipoMaterial {
  IconData get icon => switch (this) {
    TipoMaterial.texto => CupertinoIcons.doc_text_fill,
    TipoMaterial.audio => CupertinoIcons.waveform,
    TipoMaterial.pdf => CupertinoIcons.doc_richtext,
    TipoMaterial.video => CupertinoIcons.play_rectangle_fill,
    TipoMaterial.link => CupertinoIcons.link,
  };

  Color color(Palette p) => switch (this) {
    TipoMaterial.texto => Brand.navy,
    TipoMaterial.audio => p.purple,
    TipoMaterial.pdf => p.red,
    TipoMaterial.video => const Color(0xFFFF0000),
    TipoMaterial.link => Brand.blue,
  };

  List<String> get extensoes => switch (this) {
    TipoMaterial.audio => const ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus'],
    TipoMaterial.pdf => const ['pdf'],
    TipoMaterial.video => const ['mp4', 'mov', 'm4v', 'webm'],
    _ => const [],
  };
}

/// "Para quem conduz": material de apoio da aula (notas, áudio, PDF, vídeo, links).
class MateriaisApoio extends ConsumerWidget {
  const MateriaisApoio({super.key, required this.estudo});
  final Estudo estudo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leader = ref.watch(roleProvider).isLeader;
    final itens = ref.watch(materiaisProvider(estudo.id)).value ?? const <MaterialApoio>[];
    if (itens.isEmpty && !leader) return const SizedBox.shrink();
    return Section(
      header: 'Para quem conduz',
      footer: 'Material de apoio da aula. Só os líderes de PG e a liderança veem.',
      trailing: leader ? NavAction(label: 'Adicionar', onPressed: () => editarMaterial(context, ref, estudo)) : null,
      children: [
        for (final m in itens)
          ListRow(
            leading: IconTile(m.tipo.icon, color: m.tipo.color(context.pal)),
            title: m.titulo,
            subtitle: [m.tipo.label, ?m.autor].join(' · '),
            onTap: () => abrirMaterial(context, m),
            onLongPress: leader ? () => editarMaterial(context, ref, estudo, m) : null,
          ),
        if (itens.isEmpty) const ListRow(title: 'Nenhum material ainda. Ex.: áudio do pastor explicando a aula.'),
      ],
    );
  }
}

Future<void> abrirMaterial(BuildContext context, MaterialApoio m) async {
  if (m.url != null) return openUrl(context, m.url!);
  await showSheet<void>(
    context,
    tall: true,
    builder: (c) => Column(
      children: [
        SheetHeader(title: m.titulo, cancel: 'Fechar'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [SelectableText(m.texto ?? '', style: c.text.bodyLarge?.copyWith(height: 1.5))],
          ),
        ),
      ],
    ),
  );
}

/// Adiciona/edita material. Áudio, PDF e vídeo podem ser enviados do aparelho
/// (Firebase Storage) ou por link (Google Drive, YouTube…).
Future<void> editarMaterial(BuildContext context, WidgetRef ref, Estudo estudo, [MaterialApoio? m]) async {
  var tipo = m?.tipo ?? TipoMaterial.audio;
  final titulo = TextEditingController(text: m?.titulo);
  final texto = TextEditingController(text: m?.texto);
  final url = TextEditingController(text: m?.url);
  double? progresso;
  String? erro;
  final files = ref.read(fileStoreProvider);
  final r = await showSheet<String>(
    context,
    tall: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) {
        Future<void> enviar() async {
          if (!files.available) {
            setS(() => erro = 'Envio de arquivos indisponível no modo demonstração. Cole um link.');
            return;
          }
          final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: tipo.extensoes);
          final f = picked.firstOrNull;
          if (f == null) return;
          if ((await f.length() ?? 0) > 100 * 1024 * 1024) {
            setS(() => erro = 'Arquivo maior que 100 MB. Para vídeos longos, use um link do YouTube.');
            return;
          }
          setS(() {
            erro = null;
            progresso = 0;
            if (titulo.text.trim().isEmpty) titulo.text = f.name.replaceAll(RegExp(r'\.[^.]+$'), '');
          });
          try {
            final safe = f.name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
            url.text = await files.upload(
              'estudos/${estudo.id}/${DateTime.now().millisecondsSinceEpoch}-$safe',
              await f.readAsBytes(),
              contentType: contentTypeFor(f.name),
              onProgress: (p) => setS(() => progresso = p),
            );
            setS(() => progresso = null);
          } catch (e) {
            setS(() {
              progresso = null;
              erro =
                  'Não foi possível enviar o arquivo. O armazenamento de arquivos do Firebase precisa estar ativado '
                  '(plano Blaze). Enquanto isso, envie o arquivo para o Google Drive e cole o link aqui.';
            });
          }
        }

        return Column(
          children: [
            SheetHeader(
              title: m == null ? 'Material de apoio' : m.titulo,
              action: progresso == null ? 'Salvar' : null,
              onAction: () => Navigator.pop(c, 'salvar'),
            ),
            Expanded(
              child: ListView(
                children: [
                  Section(
                    children: [
                      ChoiceRow<TipoMaterial>(
                        label: 'Tipo',
                        value: tipo,
                        options: {for (final t in TipoMaterial.values) t: '${t.label} · ${t.descricao}'},
                        onChanged: (v) => setS(() => tipo = v ?? tipo),
                      ),
                      FieldRow(controller: titulo, label: 'Título', placeholder: 'Ex.: Explicação da aula'),
                    ],
                  ),
                  if (tipo == TipoMaterial.texto)
                    Section(
                      children: [
                        FieldRow(controller: texto, placeholder: 'Notas para os líderes', maxLines: 30, minLines: 10),
                      ],
                    )
                  else
                    Section(
                      footer: tipo == TipoMaterial.audio
                          ? 'Grave o áudio no telemóvel (WhatsApp ou Gravador) e envie o arquivo, ou cole um link do Google Drive.'
                          : null,
                      children: [
                        FieldRow(
                          controller: url,
                          label: 'Link',
                          placeholder: 'https://…',
                          keyboardType: TextInputType.url,
                        ),
                        if (tipo.extensoes.isNotEmpty)
                          ListRow(
                            leading: Icon(CupertinoIcons.cloud_upload, color: c.pal.accent),
                            title: progresso == null
                                ? 'Enviar arquivo do aparelho'
                                : 'Enviando… ${((progresso ?? 0) * 100).round()}%',
                            accent: true,
                            onTap: progresso == null ? enviar : null,
                          ),
                      ],
                    ),
                  if (erro != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                      child: Text(erro!, style: TextStyle(color: c.pal.red, fontSize: 14)),
                    ),
                  if (m != null)
                    Section(
                      children: [
                        ListRow(title: 'Remover material', destructive: true, onTap: () => Navigator.pop(c, 'excluir')),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
  if (r != null && context.mounted) {
    final repo = ref.read(repoProvider);
    if (r == 'excluir') {
      await guard(context, () => repo.deleteMaterial(estudo.id, m!.id), success: 'Removido');
    } else if (titulo.text.trim().isEmpty) {
      toast(context, 'Dê um título ao material.');
    } else if (tipo != TipoMaterial.texto && !isValidUrl(url.text)) {
      toast(context, 'Link inválido.');
    } else if (tipo != TipoMaterial.texto && url.text.trim().isEmpty) {
      toast(context, 'Envie um arquivo ou cole um link.');
    } else {
      final user = ref.read(currentUserProvider).value;
      await guard(
        context,
        () => repo.saveMaterial(
          estudo.id,
          MaterialApoio(
            id: m?.id ?? '',
            tipo: tipo,
            titulo: titulo.text,
            texto: tipo == TipoMaterial.texto ? texto.text.trim() : null,
            url: tipo == TipoMaterial.texto ? null : url.text.trim(),
            autor: m?.autor ?? user?.name,
            createdAt: m?.createdAt ?? '',
          ),
        ),
        success: 'Material salvo',
      );
    }
  }
  for (final x in [titulo, texto, url]) {
    x.dispose();
  }
}
