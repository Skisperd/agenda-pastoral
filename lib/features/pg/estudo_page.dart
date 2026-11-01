import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/share.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';
import 'pg_page.dart';

/// Estudo Bíblico Indutivo para o pequeno grupo: método, perguntas, orientação
/// para quem conduz e espaço para as respostas (guardadas no próprio aparelho).
class EstudoPage extends ConsumerStatefulWidget {
  const EstudoPage({super.key, required this.id});
  final String id;

  @override
  ConsumerState<EstudoPage> createState() => _EstudoPageState();
}

class _EstudoPageState extends ConsumerState<EstudoPage> {
  final _ctrls = <int, TextEditingController>{};
  SharedPreferences? _prefs;
  Map<String, dynamic>? _metodo;

  String _key(int i) => 'ebi:${widget.id}:$i';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) {
          if (!mounted) return;
          setState(() {
            _prefs = p;
            for (final e in _ctrls.entries) {
              e.value.text = p.getString(_key(e.key)) ?? '';
            }
          });
        })
        .catchError((_) {});
    rootBundle
        .loadString('assets/estudos/atos.json')
        .then((s) {
          if (mounted) {
            setState(() => _metodo = (jsonDecode(s) as Map<String, dynamic>)['metodo'] as Map<String, dynamic>?);
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(int i) => _ctrls.putIfAbsent(i, () {
    final c = TextEditingController(text: _prefs?.getString(_key(i)) ?? '');
    c.addListener(() => _prefs?.setString(_key(i), c.text));
    return c;
  });

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(estudoProvider(widget.id));
    final manage = ref.watch(roleProvider).canPublish;
    final atual = ref.watch(pgConfigProvider).value?.estudoAtual == widget.id;
    final pal = context.pal;
    if (e == null) {
      return AppScaffold(
        title: 'Estudo',
        large: false,
        slivers: [
          SliverToBoxAdapter(
            child: ref.watch(estudosProvider).isLoading
                ? const SizedBox.shrink()
                : const EmptyState(icon: CupertinoIcons.book, title: 'Estudo não encontrado'),
          ),
        ],
      );
    }
    return AppScaffold(
      title: e.referencia,
      large: false,
      previousPageTitle: 'Pequenos grupos',
      maxWidth: kFormWidth,
      actions: [
        NavAction(
          icon: CupertinoIcons.square_arrow_up,
          tooltip: 'Enviar perguntas',
          onPressed: () => shareText(context, e.textoWhatsApp),
        ),
        if (manage) NavAction(label: 'Editar', onPressed: () => editarEstudo(context, ref, e)),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: Brand.heroGradient, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESTUDO BÍBLICO INDUTIVO${atual ? ' · ESTA SEMANA' : ''}',
                    style: trackedLabel(Brand.gold, size: 11),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    e.referencia,
                    style: const TextStyle(
                      fontFamily: brandFont,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  if (e.titulo.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(e.titulo, style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 17)),
                  ],
                  if (e.resumo != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      e.resumo!,
                      style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 14.5, height: 1.4),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (manage && !atual)
          SliverToBoxAdapter(
            child: NoticeCard(
              icon: CupertinoIcons.star_fill,
              title: 'Marcar como estudo desta semana',
              color: Brand.navy,
              onTap: () => guard(
                context,
                () => ref.read(repoProvider).setEstudoAtual(e.id),
                success: 'Estudo da semana atualizado',
              ),
            ),
          ),
        if (_metodo != null) SliverToBoxAdapter(child: _Metodo(_metodo!)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 4),
            child: Text(
              'Perguntas',
              style: context.text.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Leia o texto, responda e só depois abra a orientação. Suas respostas ficam guardadas neste aparelho.',
              style: context.text.bodySmall,
            ),
          ),
        ),
        for (final (i, p) in e.perguntas.indexed)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IndexBadge(i + 1),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (p.tipo != null)
                                Text(p.tipo!.toUpperCase(), style: trackedLabel(pal.secondaryLabel, size: 10)),
                              Text(
                                p.texto,
                                style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w500, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    CupertinoTextField(
                      controller: _ctrl(i),
                      placeholder: 'Sua resposta…',
                      minLines: 2,
                      maxLines: 8,
                      padding: const EdgeInsets.all(10),
                      style: context.text.bodyLarge?.copyWith(fontSize: 15),
                      decoration: BoxDecoration(color: pal.background, borderRadius: BorderRadius.circular(10)),
                    ),
                    if (p.guia != null && p.guia!.isNotEmpty)
                      Material(
                        type: MaterialType.transparency,
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 4),
                            title: Text(
                              'Ver orientação',
                              style: TextStyle(color: pal.accent, fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: pal.accent.withValues(alpha: .08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: SelectableText(
                                  p.guia!,
                                  style: context.text.bodyLarge?.copyWith(fontSize: 15, height: 1.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        if (e.frase != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Brand.gold.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('EM UMA FRASE · PARA TRANSMITIR', style: trackedLabel(const Color(0xFF8A6A1F), size: 11)),
                    const SizedBox(height: 6),
                    Text(e.frase!, style: context.text.bodyLarge?.copyWith(fontSize: 16.5, height: 1.4)),
                  ],
                ),
              ),
            ),
          ),
        if (e.fontes.isNotEmpty)
          SliverToBoxAdapter(
            child: Section(
              header: 'Fontes das perguntas',
              children: [for (final f in e.fontes) ListRow(title: f)],
            ),
          ),
      ],
    );
  }
}

/// Método do Estudo Bíblico Indutivo, recolhido por padrão.
class _Metodo extends StatelessWidget {
  const _Metodo(this.m);
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final etapas = [for (final e in (m['etapas'] as List? ?? const [])) (e as List).cast<String>()];
    final principios = [for (final e in (m['principios'] as List? ?? const [])) (e as List).cast<String>()];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: context.pal.card,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(CupertinoIcons.info_circle_fill, color: Brand.navy),
              title: Text('Como estudar (método EBI)', style: context.text.titleSmall),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in etapas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${e[0]}: ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: e[1]),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text('Princípios de interpretação', style: context.text.titleSmall),
                const SizedBox(height: 4),
                for (final (i, p) in principios.indexed)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${i + 1}. ${p[0]}. ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: p[1]),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
