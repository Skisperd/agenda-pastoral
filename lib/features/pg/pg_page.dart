import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/pickers.dart';
import '../../core/share.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/pg.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';

/// Pequenos grupos: onde e quando se reúnem, o estudo da semana e quem procurar.
class PgPage extends ConsumerWidget {
  const PgPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    final manage = role.canPublish;
    final cfg = ref.watch(pgConfigProvider).value ?? const PgConfig();
    final grupos = [
      for (final g in ref.watch(gruposProvider).value ?? const <Grupo>[])
        if (g.ativo || manage) g,
    ];
    final atual = ref.watch(estudoAtualProvider);
    final estudos = ref.watch(estudosProvider).value ?? const <Estudo>[];
    final pedidos = [
      for (final p in ref.watch(pgPedidosProvider).value ?? const <Map<String, dynamic>>[])
        if (p['atendido'] != true) p,
    ];
    final pal = context.pal;
    return AppScaffold(
      title: 'Pequenos grupos',
      previousPageTitle: 'Mais',
      actions: [
        if (manage)
          NavAction(icon: CupertinoIcons.add, tooltip: 'Novo grupo', onPressed: () => editarGrupo(context, ref)),
        if (manage)
          NavAction(icon: CupertinoIcons.gear, tooltip: 'Configurar', onPressed: () => _configurar(context, ref, cfg)),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: Brand.heroGradient, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(CupertinoIcons.person_3_fill, color: Brand.gold, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cfg.titulo.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: brandFont,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    cfg.texto,
                    style: TextStyle(color: Colors.white.withValues(alpha: .9), fontSize: 15, height: 1.35),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (manage && pedidos.isNotEmpty)
          SliverToBoxAdapter(
            child: NoticeCard(
              icon: CupertinoIcons.person_badge_plus_fill,
              title: pedidos.length == 1 ? '1 pessoa quer participar' : '${pedidos.length} pessoas querem participar',
              message: pedidos.take(3).map((p) => p['nome']).join(', '),
              color: pal.orange,
              onTap: () => _pedidos(context, ref),
            ),
          ),
        SliverToBoxAdapter(
          child: Section(
            header: 'Estudo desta semana',
            trailing: estudos.isEmpty
                ? null
                : NavAction(label: 'Todos', onPressed: () => _todosEstudos(context, ref, estudos)),
            children: [
              if (atual != null)
                ListRow(
                  leading: const IconTile(CupertinoIcons.book_fill, color: Brand.navy),
                  title: atual.referencia,
                  subtitle: atual.titulo,
                  onTap: () => context.push('/mais/pgs/estudo/${atual.id}'),
                )
              else
                ListRow(
                  title: estudos.isEmpty ? 'Nenhum estudo cadastrado' : 'Escolha o estudo da semana',
                  subtitle: manage && estudos.isEmpty ? 'Importe a série de Atos (Estudo Bíblico Indutivo)' : null,
                  accent: manage,
                  onTap: !manage
                      ? null
                      : estudos.isEmpty
                      ? () => importarAtos(context, ref)
                      : () => _todosEstudos(context, ref, estudos),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            children: [
              for (final wd in [1, 2, 3, 4, 5, 6, 7])
                if (grupos.any((g) => g.weekday == wd))
                  Section(
                    header: '${capitalize(weekdayNames[wd - 1])}${wd <= 5 ? '-feira' : ''}',
                    children: [
                      for (final g in grupos)
                        if (g.weekday == wd)
                          ListRow(
                            leading: IconTile(CupertinoIcons.location_solid, color: g.ativo ? Brand.navy : pal.gray),
                            titleWidget: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: g.local,
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  if (g.lider != null) TextSpan(text: ': ${g.lider}'),
                                ],
                              ),
                              style: context.text.bodyLarge,
                            ),
                            subtitle: [g.hora, if (!g.ativo) 'pausado', ?g.descricao].join(' · '),
                            onTap: () => manage ? editarGrupo(context, ref, g) : _participar(context, ref, g, cfg),
                          ),
                    ],
                  ),
              if (grupos.isEmpty)
                EmptyState(
                  icon: CupertinoIcons.person_3,
                  title: 'Nenhum grupo cadastrado',
                  message: manage ? 'Toque em + para cadastrar os grupos (local, dia, hora e quem conduz).' : null,
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PARA MAIS INFORMAÇÕES', style: trackedLabel(Brand.navy, size: 12)),
                  const SizedBox(height: 6),
                  Text(
                    'Se deseja participar de um Pequeno Grupo ou esclarecer alguma dúvida'
                    '${cfg.contatoNome == null ? ', fale com a liderança.' : ', entre em contato com o ${cfg.contatoNome}.'}',
                    style: context.text.bodyLarge?.copyWith(fontSize: 15.5),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      TintButton(
                        label: 'Quero participar',
                        icon: CupertinoIcons.hand_raised_fill,
                        onPressed: () => _participar(context, ref, null, cfg),
                      ),
                      if (cfg.contatoTelefone != null)
                        TintButton(
                          label: 'WhatsApp',
                          icon: CupertinoIcons.chat_bubble_text_fill,
                          color: pal.green,
                          onPressed: () => openWhatsApp(context, cfg.contatoTelefone!),
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
  }

  Future<void> _participar(BuildContext context, WidgetRef ref, Grupo? g, PgConfig cfg) async {
    final user = ref.read(currentUserProvider).value!;
    final me = ref.read(myMemberProvider).value;
    final msg = await promptText(
      context,
      title: g == null ? 'Quero participar de um PG' : 'Participar · ${g.local}',
      message: g == null
          ? 'A liderança vai indicar o grupo mais perto de você.'
          : '${capitalize(weekdayNames[g.weekday - 1])} às ${g.hora}${g.lider == null ? '' : ', com ${g.lider}'}.',
      placeholder: 'Onde você mora? Alguma observação? (opcional)',
      ok: 'Enviar',
    );
    if (msg == null || !context.mounted) return;
    final ok = await guard(
      context,
      () => ref
          .read(repoProvider)
          .pedirGrupo(
            uid: user.uid,
            nome: me?.name ?? user.name,
            telefone: me?.phone,
            grupo: g,
            mensagem: msg.isEmpty ? null : msg,
          ),
      success: 'Pedido enviado. A liderança vai falar com você.',
    );
    final tel = g?.telefone ?? cfg.contatoTelefone;
    if (ok && tel != null && context.mounted) {
      await openWhatsApp(
        context,
        tel,
        text:
            'Olá! Sou ${me?.name ?? user.name} e gostaria de participar do pequeno grupo${g == null ? '' : ' de ${g.local}'}.',
      );
    }
  }

  Future<void> _todosEstudos(BuildContext context, WidgetRef ref, List<Estudo> estudos) async {
    final manage = ref.read(roleProvider).canPublish;
    final atualId = ref.read(pgConfigProvider).value?.estudoAtual;
    await showSheet<void>(
      context,
      tall: true,
      builder: (c) => Column(
        children: [
          SheetHeader(
            title: 'Estudos',
            cancel: 'Fechar',
            action: manage ? 'Novo' : null,
            onAction: () {
              Navigator.pop(c);
              editarEstudo(context, ref);
            },
          ),
          Expanded(
            child: ListView(
              children: [
                Section(
                  footer: manage ? 'Segure um estudo para marcá-lo como o desta semana ou editar.' : null,
                  children: [
                    for (final e in estudos)
                      ListRow(
                        leading: Icon(
                          e.id == atualId ? CupertinoIcons.star_fill : CupertinoIcons.book,
                          color: e.id == atualId ? Brand.gold : c.pal.accent,
                        ),
                        title: e.referencia,
                        subtitle: '${e.titulo} · ${e.perguntas.length} perguntas',
                        onTap: () {
                          Navigator.pop(c);
                          context.push('/mais/pgs/estudo/${e.id}');
                        },
                        onLongPress: !manage
                            ? null
                            : () async {
                                final a = await showActionSheet<String>(
                                  c,
                                  title: e.referencia,
                                  actions: const [
                                    SheetAction('Estudo desta semana', 'atual', icon: CupertinoIcons.star),
                                    SheetAction('Editar', 'editar', icon: CupertinoIcons.pencil),
                                  ],
                                );
                                if (a == null || !c.mounted) return;
                                Navigator.pop(c);
                                if (a == 'atual') {
                                  await guard(
                                    context,
                                    () => ref.read(repoProvider).setEstudoAtual(e.id),
                                    success: 'Estudo da semana: ${e.referencia}',
                                  );
                                } else if (context.mounted) {
                                  await editarEstudo(context, ref, e);
                                }
                              },
                      ),
                  ],
                ),
                if (manage)
                  Section(
                    children: [
                      ListRow(
                        title: 'Importar série de Atos (EBI)',
                        subtitle: 'Atos 13:1–12, 13:13–52 e 14:1–7, com orientações',
                        accent: true,
                        onTap: () {
                          Navigator.pop(c);
                          importarAtos(context, ref);
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pedidos(BuildContext context, WidgetRef ref) => showSheet<void>(
    context,
    tall: true,
    builder: (c) => Consumer(
      builder: (c, ref, _) {
        final list = ref.watch(pgPedidosProvider).value ?? const <Map<String, dynamic>>[];
        return Column(
          children: [
            const SheetHeader(title: 'Querem participar', cancel: 'Fechar'),
            Expanded(
              child: ListView(
                children: [
                  Section(
                    footer: 'Toque para marcar como atendido; segure para abrir o WhatsApp.',
                    children: [
                      for (final p in list)
                        ListRow(
                          leading: Icon(
                            p['atendido'] == true ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                            color: p['atendido'] == true ? c.pal.green : c.pal.tertiaryLabel,
                          ),
                          title: p['nome'] as String? ?? '',
                          subtitle: [
                            p['grupo'] as String? ?? 'qualquer grupo',
                            ?p['mensagem'] as String?,
                            if ((p['createdAt'] as String?)?.isNotEmpty ?? false) fmtDateTime(p['createdAt'] as String),
                          ].join(' · '),
                          maxSubtitleLines: 4,
                          onTap: () =>
                              ref.read(repoProvider).setPedidoAtendido(p['id'] as String, p['atendido'] != true),
                          onLongPress: p['telefone'] == null ? null : () => openWhatsApp(c, p['telefone'] as String),
                        ),
                      if (list.isEmpty) const ListRow(title: 'Nenhum pedido'),
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

  Future<void> _configurar(BuildContext context, WidgetRef ref, PgConfig cfg) async {
    final titulo = TextEditingController(text: cfg.titulo);
    final texto = TextEditingController(text: cfg.texto);
    final nome = TextEditingController(text: cfg.contatoNome);
    final tel = TextEditingController(text: cfg.contatoTelefone);
    final r = await showSheet<bool>(
      context,
      tall: true,
      builder: (c) => Column(
        children: [
          SheetHeader(title: 'Pequenos grupos', action: 'Salvar', onAction: () => Navigator.pop(c, true)),
          Expanded(
            child: ListView(
              children: [
                Section(
                  header: 'Apresentação',
                  children: [
                    FieldRow(controller: titulo, placeholder: 'Título'),
                    FieldRow(controller: texto, placeholder: 'Texto', maxLines: 6, minLines: 3),
                  ],
                ),
                Section(
                  header: 'Contato',
                  footer: 'Quem atende quem quer participar.',
                  children: [
                    FieldRow(controller: nome, label: 'Nome', placeholder: 'presbítero Roberto'),
                    FieldRow(
                      controller: tel,
                      label: 'WhatsApp',
                      placeholder: '912 345 678',
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (r == true && context.mounted) {
      String? v(TextEditingController x) => x.text.trim().isEmpty ? null : x.text.trim();
      await guard(
        context,
        () => ref
            .read(repoProvider)
            .savePgConfig(
              PgConfig(
                titulo: titulo.text.trim().isEmpty ? const PgConfig().titulo : titulo.text.trim(),
                texto: texto.text.trim().isEmpty ? const PgConfig().texto : texto.text.trim(),
                contatoNome: v(nome),
                contatoTelefone: v(tel),
                estudoAtual: cfg.estudoAtual,
              ),
            ),
        success: 'Salvo',
      );
    }
    for (final x in [titulo, texto, nome, tel]) {
      x.dispose();
    }
  }
}

/// Grava a série de Atos que acompanha o app e marca o primeiro como o da semana.
Future<void> importarAtos(BuildContext context, WidgetRef ref) async {
  final ok = await guard(context, () async {
    final serie = jsonDecode(await rootBundle.loadString('assets/estudos/atos.json')) as Map<String, dynamic>;
    final repo = ref.read(repoProvider);
    await repo.importEstudos(serie);
    if (ref.read(pgConfigProvider).value?.estudoAtual == null) {
      final first = ((serie['estudos'] as List).first as Map)['id'] as String;
      await repo.setEstudoAtual(first);
    }
  }, success: 'Estudos de Atos importados');
  if (ok && context.mounted) toast(context, 'Estudos de Atos importados');
}

Future<void> editarGrupo(BuildContext context, WidgetRef ref, [Grupo? g]) async {
  final local = TextEditingController(text: g?.local);
  final lider = TextEditingController(text: g?.lider);
  final tel = TextEditingController(text: g?.telefone);
  final desc = TextEditingController(text: g?.descricao);
  var weekday = g?.weekday ?? 4;
  String? time = g?.time ?? '20:00';
  var ativo = g?.ativo ?? true;
  final r = await showSheet<String>(
    context,
    tall: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) => Column(
        children: [
          SheetHeader(
            title: g == null ? 'Novo grupo' : 'Grupo',
            action: 'Salvar',
            onAction: () => Navigator.pop(c, 'salvar'),
          ),
          Expanded(
            child: ListView(
              children: [
                Section(
                  footer: 'Mostre só a zona (ex.: São Mamede). A morada da casa fica com quem conduz.',
                  children: [
                    FieldRow(controller: local, label: 'Local', placeholder: 'São Mamede', autofocus: g == null),
                    ChoiceRow<int>(
                      label: 'Dia',
                      value: weekday,
                      options: {
                        for (final d in [1, 2, 3, 4, 5, 6, 7]) d: capitalize(weekdayNames[d - 1]),
                      },
                      onChanged: (v) => setS(() => weekday = v ?? weekday),
                    ),
                    TimeRow(label: 'Hora', value: time, onChanged: (v) => setS(() => time = v)),
                    FieldRow(controller: lider, label: 'Conduz', placeholder: 'Marco'),
                    FieldRow(
                      controller: tel,
                      label: 'WhatsApp',
                      placeholder: 'Opcional',
                      keyboardType: TextInputType.phone,
                    ),
                    FieldRow(controller: desc, placeholder: 'Observação (ex.: casais, jovens)'),
                    ListRow(
                      title: 'Ativo',
                      trailing: AppSwitch(value: ativo, onChanged: (v) => setS(() => ativo = v)),
                    ),
                  ],
                ),
                if (g != null)
                  Section(
                    children: [
                      ListRow(title: 'Excluir grupo', destructive: true, onTap: () => Navigator.pop(c, 'excluir')),
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
    String? v(TextEditingController x) => x.text.trim().isEmpty ? null : x.text.trim();
    if (r == 'excluir') {
      await guard(context, () => repo.deleteGrupo(g!.id), success: 'Grupo excluído');
    } else if (local.text.trim().isNotEmpty) {
      await guard(
        context,
        () => repo.saveGrupo(
          Grupo(
            id: g?.id ?? '',
            local: local.text,
            weekday: weekday,
            time: time ?? '20:00',
            lider: v(lider),
            telefone: v(tel),
            descricao: v(desc),
            ativo: ativo,
          ),
        ),
        success: 'Grupo salvo',
      );
    }
  }
  for (final x in [local, lider, tel, desc]) {
    x.dispose();
  }
}

/// Cria/edita um estudo: uma pergunta por linha. Orientações já existentes são mantidas.
Future<void> editarEstudo(BuildContext context, WidgetRef ref, [Estudo? e]) async {
  final refc = TextEditingController(text: e?.referencia);
  final titulo = TextEditingController(text: e?.titulo);
  final resumo = TextEditingController(text: e?.resumo);
  final perguntas = TextEditingController(text: e?.perguntas.map((p) => p.texto).join('\n'));
  final r = await showSheet<String>(
    context,
    tall: true,
    builder: (c) => Column(
      children: [
        SheetHeader(
          title: e == null ? 'Novo estudo' : 'Estudo',
          action: 'Salvar',
          onAction: () => Navigator.pop(c, 'salvar'),
        ),
        Expanded(
          child: ListView(
            children: [
              Section(
                children: [
                  FieldRow(controller: refc, label: 'Texto', placeholder: 'Atos 14:8–20', autofocus: e == null),
                  FieldRow(controller: titulo, label: 'Título', placeholder: 'Opcional'),
                  FieldRow(controller: resumo, placeholder: 'Resumo da passagem (opcional)', maxLines: 4),
                ],
              ),
              Section(
                header: 'Perguntas',
                footer: 'Uma pergunta por linha.',
                children: [
                  FieldRow(controller: perguntas, placeholder: '1ª pergunta\n2ª pergunta…', maxLines: 20, minLines: 8),
                ],
              ),
              if (e != null)
                Section(
                  children: [
                    ListRow(title: 'Excluir estudo', destructive: true, onTap: () => Navigator.pop(c, 'excluir')),
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
  );
  if (r != null && context.mounted) {
    final repo = ref.read(repoProvider);
    if (r == 'excluir') {
      await guard(context, () => repo.deleteEstudo(e!.id), success: 'Estudo excluído');
    } else if (refc.text.trim().isNotEmpty) {
      final antigas = {for (final p in e?.perguntas ?? const <Pergunta>[]) p.texto: p};
      final lista = [
        for (final l in perguntas.text.split('\n'))
          if (l.trim().isNotEmpty) antigas[l.trim()] ?? Pergunta(texto: l.trim()),
      ];
      final estudos = ref.read(estudosProvider).value ?? const <Estudo>[];
      await guard(
        context,
        () => repo.saveEstudo(
          Estudo(
            id: e?.id ?? '',
            referencia: refc.text,
            titulo: titulo.text,
            livro: e?.livro,
            ordem: e?.ordem ?? (estudos.isEmpty ? 1 : estudos.last.ordem + 1),
            resumo: resumo.text.trim().isEmpty ? null : resumo.text.trim(),
            frase: e?.frase,
            perguntas: lista,
            fontes: e?.fontes ?? const [],
          ),
        ),
        success: 'Estudo salvo',
      );
    }
  }
  for (final x in [refc, titulo, resumo, perguntas]) {
    x.dispose();
  }
}
