import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/links.dart';
import '../../core/share.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/boletim.dart';
import '../../data/models/conteudo.dart';
import '../../data/models/igreja.dart';
import '../../data/providers.dart';

/// Boletim da semana, no mesmo formato do boletim impresso da igreja.
class BoletimPage extends ConsumerStatefulWidget {
  const BoletimPage({super.key, this.id});

  /// Domingo do boletim (yyyy-MM-dd); sem ele, o da semana.
  final String? id;

  @override
  ConsumerState<BoletimPage> createState() => _BoletimPageState();
}

class _BoletimPageState extends ConsumerState<BoletimPage> {
  String? _id;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(roleProvider);
    final all = ref.watch(boletinsProvider).value ?? const <Boletim>[];
    final id = _id ?? widget.id;
    final b = id == null ? ref.watch(boletimAtualProvider) : all.where((x) => x.id == id).firstOrNull;
    final igreja = ref.watch(igrejaProvider).value ?? const IgrejaConfig();
    return AppScaffold(
      title: 'Boletim',
      large: false,
      previousPageTitle: 'Início',
      maxWidth: kFormWidth,
      actions: [
        if (all.length > 1)
          NavAction(
            icon: CupertinoIcons.calendar,
            tooltip: 'Boletins anteriores',
            onPressed: () async {
              final pick = await showActionSheet<String>(
                context,
                title: 'Boletins',
                actions: [
                  for (final x in all.take(12)) SheetAction('${x.periodo}${x.publicado ? '' : ' · rascunho'}', x.id),
                ],
              );
              if (pick != null) setState(() => _id = pick);
            },
          ),
        if (b != null)
          NavAction(
            icon: CupertinoIcons.square_arrow_up,
            tooltip: 'Compartilhar',
            onPressed: () => shareText(context, boletimTexto(b, igreja, ref.read(weeklyProvider).value ?? const [])),
          ),
        if (role.canPublish)
          NavAction(
            label: b == null ? 'Criar' : 'Editar',
            onPressed: () => context.push('/mais/boletim/editar${b == null ? '' : '?id=${b.id}'}'),
          ),
      ],
      slivers: [
        if (b == null)
          SliverToBoxAdapter(
            child: EmptyState(
              icon: CupertinoIcons.doc_richtext,
              title: 'Boletim ainda não publicado',
              message: role.canPublish ? 'Toque em Criar para montar o boletim desta semana.' : null,
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: _Capa(b: b, igreja: igreja),
          ),
          if (!b.publicado)
            SliverToBoxAdapter(
              child: NoticeCard(
                icon: CupertinoIcons.eye_slash_fill,
                title: 'Rascunho',
                message: 'Só pastores e presbíteros veem. Publique no editor.',
                color: context.pal.orange,
              ),
            ),
          if (b.avisos.isNotEmpty)
            SliverToBoxAdapter(
              child: _Bloco(
                icon: CupertinoIcons.speaker_2_fill,
                titulo: 'Avisos da semana',
                child: Column(children: [for (final a in b.avisos) _ItemLinha(a, sino: a.destaque)]),
              ),
            ),
          SliverToBoxAdapter(child: _Agenda(domingo: b.domingo)),
          if (b.oracao.isNotEmpty)
            SliverToBoxAdapter(
              child: _Bloco(
                icon: CupertinoIcons.heart_circle_fill,
                titulo: 'Ore conosco',
                child: Column(children: [for (final a in b.oracao) _ItemLinha(a)]),
              ),
            ),
          if (b.estudos.isNotEmpty)
            SliverToBoxAdapter(
              child: _Bloco(
                icon: CupertinoIcons.book_fill,
                titulo: 'O que estamos a estudar',
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final e in b.estudos)
                      Tappable(
                        onTap: e.area.toLowerCase().contains('pequeno') ? () => context.go('/mais/pgs') : null,
                        child: Container(
                          width: 150,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.pal.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.area, style: context.text.titleSmall?.copyWith(color: Brand.navy)),
                              const SizedBox(height: 2),
                              Text(e.tema, style: context.text.bodyMedium),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(child: ContribuaBloco(igreja: igreja)),
          SliverToBoxAdapter(child: RodapeIgreja(igreja: igreja)),
        ],
      ],
    );
  }
}

class _Capa extends StatelessWidget {
  const _Capa({required this.b, required this.igreja});
  final Boletim b;
  final IgrejaConfig igreja;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: Brand.heroGradient, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Brand.paper, borderRadius: BorderRadius.circular(8)),
                child: const BrandMark(height: 28),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  igreja.slogan.toUpperCase(),
                  style: trackedLabel(Colors.white.withValues(alpha: .75), size: 10.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'BOLETIM',
            style: TextStyle(
              fontFamily: brandFont,
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
              letterSpacing: 3,
            ),
          ),
          Text(
            'DA SEMANA',
            style: TextStyle(
              fontFamily: brandFont,
              fontSize: 26,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: .85),
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            b.periodo,
            style: const TextStyle(color: Brand.gold, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

/// Bloco com faixa de título e ícone, como no boletim impresso.
class _Bloco extends StatelessWidget {
  const _Bloco({required this.icon, required this.titulo, required this.child});
  final IconData icon;
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: context.pal.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: Brand.stone.withValues(alpha: .55),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Brand.navy,
                      borderRadius: BorderRadius.only(bottomRight: Radius.circular(18)),
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      titulo.toUpperCase(),
                      maxLines: 2,
                      style: const TextStyle(
                        fontFamily: brandFont,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Brand.navy,
                        letterSpacing: .5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.all(16), child: child),
          ],
        ),
      ),
    ),
  );
}

class _ItemLinha extends StatelessWidget {
  const _ItemLinha(this.i, {this.sino = false});
  final ItemBoletim i;
  final bool sino;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3, right: 10),
          child: sino
              ? Icon(CupertinoIcons.bell_fill, size: 16, color: context.pal.red)
              : const Icon(CupertinoIcons.circle_fill, size: 7, color: Brand.navy),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: i.titulo,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.navy),
                ),
                if (i.texto.isNotEmpty) TextSpan(text: ' — ${i.texto}'),
              ],
            ),
            style: context.text.bodyLarge?.copyWith(fontSize: 15.5, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

/// Programação da semana do boletim (domingo a sábado), a partir da Programação.
class _Agenda extends ConsumerWidget {
  const _Agenda({required this.domingo});
  final DateTime domingo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekly = [
      for (final p in ref.watch(weeklyProvider).value ?? const <Programacao>[])
        if (p.active) p,
    ];
    final eventos = [
      for (final e in ref.watch(eventsProvider).value ?? const <Evento>[])
        if (e.published && !e.start.isBefore(domingo) && e.start.isBefore(addDays(domingo, 7))) e,
    ];
    if (weekly.isEmpty && eventos.isEmpty) return const SizedBox.shrink();
    final dias = [7, 1, 2, 3, 4, 5, 6];
    return _Bloco(
      icon: CupertinoIcons.calendar,
      titulo: 'Agenda',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final wd in dias)
            if (weekly.any((p) => p.weekday == wd) || eventos.any((e) => e.start.weekday == wd)) ...[
              Text(
                capitalize(weekdayNames[wd - 1]),
                style: context.text.titleMedium?.copyWith(color: Brand.navy, fontWeight: FontWeight.w700),
              ),
              Container(height: 2, width: 160, color: Brand.navy, margin: const EdgeInsets.only(top: 4, bottom: 8)),
              for (final p in weekly)
                if (p.weekday == wd)
                  _Hora(
                    p.title,
                    '${p.time.replaceAll(':', 'h').replaceAll('h00', 'h')}'
                    '${p.endTime == null ? '' : ' – ${p.endTime!.replaceAll(':', 'h')}'}',
                  ),
              for (final e in eventos)
                if (e.start.weekday == wd)
                  _Hora(e.title, fmtHour(e.start), onTap: () => context.push('/agenda/evento/${e.id}')),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _Hora extends StatelessWidget {
  const _Hora(this.titulo, this.hora, {this.onTap});
  final String titulo;
  final String hora;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Tappable(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(titulo, style: context.text.bodyLarge?.copyWith(fontWeight: FontWeight.w600, fontSize: 15.5)),
          ),
          Text(
            hora,
            style: TextStyle(fontFamily: numFont, fontSize: 14, color: context.pal.secondaryLabel),
          ),
        ],
      ),
    ),
  );
}

/// Dados bancários e identificação das ofertas.
class ContribuaBloco extends StatelessWidget {
  const ContribuaBloco({super.key, required this.igreja});
  final IgrejaConfig igreja;

  @override
  Widget build(BuildContext context) {
    if (igreja.iban == null && igreja.pix == null && igreja.ofertas.isEmpty) return const SizedBox.shrink();
    Widget copia(String label, String valor) => Tappable(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: valor.replaceAll(' ', '')));
        if (context.mounted) toast(context, '$label copiado');
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Text(
              '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Brand.navy),
            ),
            Expanded(
              child: Text(valor, style: const TextStyle(fontFamily: numFont, fontSize: 13.5)),
            ),
            Icon(CupertinoIcons.doc_on_doc, size: 16, color: context.pal.accent),
          ],
        ),
      ),
    );
    return _Bloco(
      icon: CupertinoIcons.gift_fill,
      titulo: 'Contribua e faça parte da missão',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (igreja.banco != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(igreja.banco!, style: context.text.titleMedium?.copyWith(color: Brand.navy)),
            ),
          if (igreja.iban != null) copia('IBAN', igreja.iban!),
          if (igreja.swift != null) copia('SWIFT', igreja.swift!),
          if (igreja.pix != null) copia('MB WAY', igreja.pix!),
          if (igreja.ofertas.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Identificação das ofertas', style: context.text.titleSmall?.copyWith(color: Brand.navy)),
            const SizedBox(height: 4),
            for (final (t, v) in igreja.ofertas)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    Text(v, style: const TextStyle(fontFamily: numFont, fontSize: 13.5)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Some os cêntimos ao valor da transferência para identificar a finalidade.',
                style: context.text.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Endereço, site e canal da igreja.
class RodapeIgreja extends StatelessWidget {
  const RodapeIgreja({super.key, required this.igreja});
  final IgrejaConfig igreja;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (igreja.address != null)
          TintButton(
            label: igreja.address!,
            icon: CupertinoIcons.location_solid,
            onPressed: () => openUrl(
              context,
              Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': igreja.address}).toString(),
            ),
          ),
        if (igreja.site != null)
          TintButton(label: 'Site', icon: CupertinoIcons.globe, onPressed: () => openUrl(context, igreja.site!)),
        if (igreja.instagram != null)
          TintButton(
            label: 'Instagram',
            icon: CupertinoIcons.camera_fill,
            onPressed: () => openUrl(context, igreja.instagram!),
          ),
        if (igreja.youtube != null)
          TintButton(
            label: 'YouTube',
            icon: CupertinoIcons.play_rectangle_fill,
            color: const Color(0xFFFF0000),
            onPressed: () => openUrl(context, igreja.youtube!),
          ),
      ],
    ),
  );
}

/// Boletim em texto para o WhatsApp.
String boletimTexto(Boletim b, IgrejaConfig igreja, List<Programacao> weekly) {
  final s = StringBuffer('*${igreja.shortName.toUpperCase()} · BOLETIM DA SEMANA*\n_${b.periodo}_\n');
  if (b.avisos.isNotEmpty) {
    s.write('\n📢 *Avisos da semana*\n');
    for (final a in b.avisos) {
      s.write('• *${a.titulo}*${a.texto.isEmpty ? '' : ' — ${a.texto}'}\n');
    }
  }
  final ativos = [
    for (final p in weekly)
      if (p.active) p,
  ];
  if (ativos.isNotEmpty) {
    s.write('\n📅 *Agenda*\n');
    for (final wd in [7, 1, 2, 3, 4, 5, 6]) {
      final doDia = [
        for (final p in ativos)
          if (p.weekday == wd) p,
      ];
      if (doDia.isEmpty) continue;
      s.write('_${capitalize(weekdayNames[wd - 1])}_\n');
      for (final p in doDia) {
        s.write('• ${p.time.replaceAll(':', 'h').replaceAll('h00', 'h')} ${p.title}\n');
      }
    }
  }
  if (b.oracao.isNotEmpty) {
    s.write('\n🙏 *Ore conosco*\n');
    for (final a in b.oracao) {
      s.write('• *${a.titulo}*${a.texto.isEmpty ? '' : ': ${a.texto}'}\n');
    }
  }
  if (b.estudos.isNotEmpty) {
    s.write('\n📖 *O que estamos a estudar*\n');
    for (final e in b.estudos) {
      s.write('• ${e.area}: ${e.tema}\n');
    }
  }
  if (igreja.iban != null) {
    s.write('\n💙 *Contribua*\n${igreja.banco == null ? '' : '${igreja.banco}\n'}IBAN: ${igreja.iban}\n');
    if (igreja.swift != null) s.write('SWIFT: ${igreja.swift}\n');
    for (final (t, v) in igreja.ofertas) {
      s.write('• $t: $v\n');
    }
  }
  if (igreja.address != null) s.write('\n📍 ${igreja.address}');
  if (igreja.site != null) s.write('\n🌐 ${igreja.site}');
  if (igreja.youtube != null) s.write('\n▶️ ${igreja.youtube}');
  return s.toString().trim();
}
