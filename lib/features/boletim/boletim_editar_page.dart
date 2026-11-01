import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/pickers.dart';
import '../../core/widgets.dart';
import '../../data/models/boletim.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';
import '../common.dart';

/// Editor do boletim da semana (pastores e presbíteros).
class BoletimEditarPage extends ConsumerStatefulWidget {
  const BoletimEditarPage({super.key, this.id});
  final String? id;

  @override
  ConsumerState<BoletimEditarPage> createState() => _BoletimEditarPageState();
}

class _BoletimEditarPageState extends ConsumerState<BoletimEditarPage> {
  late String _domingo = widget.id ?? ymd(domingoDe(DateTime.now()));
  List<ItemBoletim> _avisos = [];
  List<ItemBoletim> _oracao = [];
  List<EstudoFrente> _estudos = [for (final a in Boletim.frentesPadrao) EstudoFrente(a, '')];
  bool _publicado = false;
  bool _loaded = false;
  bool _saving = false;

  void _load(Boletim b) {
    _domingo = b.inicio;
    _avisos = [...b.avisos];
    _oracao = [...b.oracao];
    _estudos = b.estudos.isEmpty ? _estudos : [...b.estudos];
    _publicado = b.publicado;
  }

  Future<void> _salvar({bool? publicar}) async {
    setState(() => _saving = true);
    final b = Boletim(
      id: _domingo,
      inicio: _domingo,
      avisos: _avisos,
      oracao: _oracao,
      estudos: [
        for (final e in _estudos)
          if (e.tema.trim().isNotEmpty) e,
      ],
      publicado: publicar ?? _publicado,
    );
    final ok = await guard(
      context,
      () => ref.read(repoProvider).saveBoletim(b),
      success: b.publicado ? 'Boletim publicado' : 'Rascunho salvo',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.go('/mais/boletim?id=$_domingo');
  }

  Future<ItemBoletim?> _editarItem(String titulo, {ItemBoletim? item, bool comDestaque = false}) async {
    final t = TextEditingController(text: item?.titulo);
    final x = TextEditingController(text: item?.texto);
    var destaque = item?.destaque ?? false;
    final r = await showSheet<String>(
      context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(title: titulo, action: 'OK', onAction: () => Navigator.pop(c, 'ok')),
              Section(
                children: [
                  FieldRow(controller: t, placeholder: 'Título (ex.: Jejum)', autofocus: item == null),
                  FieldRow(controller: x, placeholder: 'Texto', maxLines: 6, minLines: 2),
                  if (comDestaque)
                    ListRow(
                      title: 'Destaque',
                      subtitle: 'Aparece com o sino vermelho',
                      trailing: AppSwitch(value: destaque, onChanged: (v) => setS(() => destaque = v)),
                    ),
                ],
              ),
              if (item != null)
                Section(
                  children: [ListRow(title: 'Remover', destructive: true, onTap: () => Navigator.pop(c, 'del'))],
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
    final out = r == 'del'
        ? const ItemBoletim(titulo: '')
        : r == 'ok' && t.text.trim().isNotEmpty
        ? ItemBoletim(titulo: t.text.trim(), texto: x.text.trim(), destaque: destaque)
        : null;
    t.dispose();
    x.dispose();
    return out;
  }

  Widget _lista(
    String header,
    List<ItemBoletim> itens,
    ValueChanged<List<ItemBoletim>> onChanged, {
    bool destaque = false,
  }) => Section(
    header: header,
    trailing: NavAction(
      label: 'Adicionar',
      onPressed: () async {
        final n = await _editarItem(header, comDestaque: destaque);
        if (n != null && n.titulo.isNotEmpty) onChanged([...itens, n]);
      },
    ),
    children: [
      for (final (i, a) in itens.indexed)
        ListRow(
          leading: destaque && a.destaque ? Icon(CupertinoIcons.bell_fill, color: context.pal.red, size: 18) : null,
          title: a.titulo,
          subtitle: a.texto.isEmpty ? null : a.texto,
          trailing: i == 0
              ? null
              : Tappable(
                  onTap: () => onChanged(
                    [...itens]
                      ..insert(i - 1, itens[i])
                      ..removeAt(i + 1),
                  ),
                  child: Icon(CupertinoIcons.arrow_up, size: 18, color: context.pal.accent),
                ),
          onTap: () async {
            final n = await _editarItem(header, item: a, comDestaque: destaque);
            if (n == null) return;
            final novo = [...itens];
            n.titulo.isEmpty ? novo.removeAt(i) : novo[i] = n;
            onChanged(novo);
          },
        ),
      if (itens.isEmpty) const ListRow(title: 'Nada ainda'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(roleProvider).canPublish) return const NoAccess(title: 'Boletim');
    final all = ref.watch(boletinsProvider).value ?? const <Boletim>[];
    if (!_loaded && widget.id != null) {
      final b = all.where((x) => x.id == widget.id).firstOrNull;
      if (b == null && ref.watch(boletinsProvider).isLoading) return const AppScaffold(title: 'Boletim', large: false);
      if (b != null) _load(b);
      _loaded = true;
    }
    final anterior = all.where((x) => x.inicio.compareTo(_domingo) < 0).firstOrNull;
    final semana = Boletim(id: _domingo, inicio: _domingo);
    return AppScaffold(
      title: 'Editar boletim',
      large: false,
      maxWidth: kFormWidth,
      leading: NavAction(label: 'Cancelar', onPressed: () => context.pop()),
      actions: [NavAction(label: 'Salvar', bold: true, onPressed: _saving ? null : _salvar)],
      slivers: [
        SliverToBoxAdapter(
          child: Section(
            header: 'Semana',
            children: [
              ListRow(
                title: 'Período',
                subtitle: semana.periodo,
                onTap: widget.id != null
                    ? null
                    : () async {
                        final d = await pickDate(context, initial: DateTime.parse(_domingo));
                        if (d != null) setState(() => _domingo = ymd(domingoDe(d)));
                      },
              ),
              if (anterior != null && widget.id == null)
                ListRow(
                  title: 'Copiar do boletim anterior',
                  subtitle: anterior.periodo,
                  accent: true,
                  onTap: () => setState(() => _load(anterior.paraSemana(_domingo))),
                ),
              ListRow(
                title: 'Publicado',
                subtitle: _publicado ? 'Todos os membros veem' : 'Rascunho: só a liderança vê',
                trailing: AppSwitch(value: _publicado, onChanged: (v) => setState(() => _publicado = v)),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: _lista('Avisos da semana', _avisos, (l) => setState(() => _avisos = l), destaque: true),
        ),
        SliverToBoxAdapter(child: _lista('Ore conosco', _oracao, (l) => setState(() => _oracao = l))),
        SliverToBoxAdapter(
          child: Section(
            header: 'O que estamos a estudar',
            footer: 'Deixe em branco o que não quiser mostrar.',
            trailing: NavAction(
              label: 'Adicionar',
              onPressed: () async {
                final area = await promptText(context, title: 'Nova frente', placeholder: 'Ex.: Mocidade');
                if (area != null && area.isNotEmpty) setState(() => _estudos = [..._estudos, EstudoFrente(area, '')]);
              },
            ),
            children: [
              for (final (i, e) in _estudos.indexed)
                ListRow(
                  title: e.area,
                  subtitle: e.tema.isEmpty ? 'Toque para preencher' : e.tema,
                  onTap: () async {
                    final t = await promptText(
                      context,
                      title: e.area,
                      placeholder: e.tema.isEmpty ? 'Ex.: 1 Pedro' : e.tema,
                    );
                    if (t == null) return;
                    setState(() => _estudos = [..._estudos]..[i] = EstudoFrente(e.area, t));
                  },
                ),
            ],
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(32, 12, 32, 0),
            child: Text(
              'A agenda vem da Programação semanal e dos eventos. Banco, IBAN e ofertas ficam em Mais › Dados da igreja.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              children: [
                PrimaryButton(label: 'Salvar e publicar', loading: _saving, onPressed: () => _salvar(publicar: true)),
                if (widget.id != null) ...[
                  const SizedBox(height: 10),
                  TintButton(
                    label: 'Excluir boletim',
                    color: context.pal.red,
                    large: true,
                    expand: true,
                    onPressed: () async {
                      if (!await confirm(context, 'Excluir este boletim?', ok: 'Excluir', destructive: true)) return;
                      if (!context.mounted) return;
                      final ok = await guard(context, () => ref.read(repoProvider).deleteBoletim(_domingo));
                      if (ok && context.mounted) context.go('/mais/boletim');
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
