import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/roles.dart';
import '../../core/widgets.dart';
import '../../data/models/escala.dart';
import '../../data/models/igreja.dart';
import '../../data/providers.dart';
import '../../domain/escala_generator.dart';
import '../common.dart';
import 'escala_detail_page.dart';

/// Monta a escala de um mês inteiro de uma vez, distribuindo de forma justa.
class EscalaGerarPage extends ConsumerStatefulWidget {
  const EscalaGerarPage({super.key});

  @override
  ConsumerState<EscalaGerarPage> createState() => _EscalaGerarPageState();
}

class _EscalaGerarPageState extends ConsumerState<EscalaGerarPage> {
  late DateTime _month = () {
    final n = DateTime.now();
    return n.day > 20 ? DateTime(n.year, n.month + 1) : DateTime(n.year, n.month);
  }();
  final _vagas = {for (final f in FuncaoDiaconal.values) f: f.defaultCount};
  final _cultosOn = <String>{};
  bool _cultosInit = false;
  int _ceia = 4;
  bool _ceiaPrimeiroDomingo = true;
  EscalaGerada? _preview;
  List<EscalaDiaconal> _drafts = const [];
  bool _saving = false;

  /// Cultos semanais (da Programação) como opções.
  List<Programacao> _cultos() => [
    for (final p in ref.watch(weeklyProvider).value ?? const <Programacao>[])
      if (p.active && p.categoria == Categoria.culto) p,
  ];

  String _key(Programacao p) => '${p.weekday}|${p.time}';

  void _gerar() {
    final cultos = [
      for (final p in _cultos())
        if (_cultosOn.contains(_key(p))) p,
    ];
    if (cultos.isEmpty) return toast(context, 'Escolha pelo menos um culto.');
    final today = ymd(DateTime.now());
    final existing = {
      for (final e in ref.read(escalasProvider).value ?? const <EscalaDiaconal>[]) '${e.date}|${e.time ?? ''}',
    };
    // Cada culto do mês vira uma "data" (data + horário) para o gerador.
    final slots = <String, (DateTime, Programacao)>{};
    for (var d = _month; d.month == _month.month; d = addDays(d, 1)) {
      for (final p in cultos) {
        if (p.weekday != d.weekday || ymd(d).compareTo(today) < 0) continue;
        final k = '${ymd(d)}|${p.time}';
        if (!existing.contains(k)) slots[k] = (d, p);
      }
    }
    if (slots.isEmpty) return toast(context, 'Todos os cultos deste mês já têm escala.');
    final primeiroDomingo = ymd(nextSunday(_month));
    final cands = candidatos(ref);
    final carga = cargaRecente(ref);
    // A Santa Ceia muda as vagas de um culto específico: gera um culto por vez,
    // acumulando a carga para manter o equilíbrio.
    final porData = <String, Map<FuncaoDiaconal, List<String>>>{};
    final vagas = <(String, FuncaoDiaconal, int)>[];
    final acumulado = {...carga};
    String? anterior;
    for (final k in slots.keys.toList()..sort()) {
      final (d, p) = slots[k]!;
      final ceia = _ceiaPrimeiroDomingo && ymd(d) == primeiroDomingo && p.weekday == 7;
      final g = const EscalaGenerator().gerar(
        datas: [k],
        vagasPorFuncao: {..._vagas, FuncaoDiaconal.ceia: ceia ? _ceia : 0},
        candidatos: [
          for (final c in cands)
            Candidato(
              id: c.id,
              name: c.name,
              funcoes: c.funcoes,
              unavailable: {
                for (final u in c.unavailable)
                  for (final s in slots.keys)
                    if (s.startsWith(u)) s,
              },
            ),
        ],
        historico: {
          for (final e in acumulado.entries) e.key: e.value,
          // Quem serviu no culto anterior pesa mais (evita cultos seguidos).
          if (anterior != null)
            for (final id in porData[anterior]!.values.expand((x) => x)) id: (acumulado[id] ?? 0) + 1,
        },
      );
      porData[k] = g.porData[k] ?? {};
      vagas.addAll(g.vagas);
      for (final id in porData[k]!.values.expand((x) => x)) {
        acumulado[id] = (acumulado[id] ?? 0) + 1;
      }
      anterior = k;
    }
    final names = {for (final c in cands) c.id: c.name};
    setState(() {
      _preview = EscalaGerada(porData, vagas);
      _drafts = [
        for (final k in porData.keys.toList()..sort())
          EscalaDiaconal(
            id: '',
            date: k.split('|').first,
            time: k.split('|').last,
            title: slots[k]!.$2.title,
            assignments: porData[k]!,
            names: {for (final id in porData[k]!.values.expand((x) => x)) id: names[id] ?? '?'},
          ),
      ];
    });
  }

  Future<void> _salvar(bool publicar) async {
    setState(() => _saving = true);
    final ok = await guard(
      context,
      () => ref.read(repoProvider).saveEscalas([for (final e in _drafts) e.copyWith(published: publicar)]),
      success: publicar ? 'Escala publicada' : 'Rascunho salvo',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) context.go('/mais/escala');
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(roleProvider).canManageEscala) return const NoAccess(title: 'Gerar escala');
    final cultos = _cultos();
    if (!_cultosInit && cultos.isNotEmpty) {
      _cultosOn.addAll([
        for (final p in cultos)
          if (p.weekday == 7) _key(p),
      ]);
      _cultosInit = true;
    }
    final cands = ref.watch(diaconiaMembersProvider).value ?? const [];
    final pal = context.pal;
    return AppScaffold(
      title: 'Gerar escala',
      large: false,
      previousPageTitle: 'Escala',
      maxWidth: kFormWidth,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'O app distribui o serviço de forma equilibrada: respeita as datas em que cada um avisou que não pode, '
              'as funções que cada um faz, evita cultos seguidos e prioriza quem serviu menos nos últimos 60 dias.',
              style: context.text.bodyMedium,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Section(
            header: 'Mês',
            children: [
              ListRow(
                leading: IconButton(
                  icon: const Icon(CupertinoIcons.chevron_left),
                  onPressed: () => setState(() {
                    _month = DateTime(_month.year, _month.month - 1);
                    _preview = null;
                  }),
                ),
                titleWidget: Text(
                  capitalize(fmtMonth(_month)),
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium,
                ),
                center: true,
                trailing: IconButton(
                  icon: const Icon(CupertinoIcons.chevron_right),
                  onPressed: () => setState(() {
                    _month = DateTime(_month.year, _month.month + 1);
                    _preview = null;
                  }),
                ),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Section(
            header: 'Cultos',
            footer: cultos.isEmpty ? 'Cadastre os cultos em Agenda › Programação.' : null,
            children: [
              for (final p in cultos)
                ListRow(
                  title: p.title,
                  subtitle: '${capitalize(weekdayNames[p.weekday - 1])} às ${p.time}',
                  trailing: AppSwitch(
                    value: _cultosOn.contains(_key(p)),
                    onChanged: (v) => setState(() {
                      v ? _cultosOn.add(_key(p)) : _cultosOn.remove(_key(p));
                      _preview = null;
                    }),
                  ),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Section(
            header: 'Pessoas por função',
            footer:
                '${cands.length} pessoas podem ser escaladas (diáconos e quem tem o ministério Diaconia no cadastro).',
            children: [
              for (final f in FuncaoDiaconal.values)
                if (f != FuncaoDiaconal.ceia)
                  _Stepper(
                    icon: f.icon,
                    color: f.color(pal),
                    label: f.label,
                    value: _vagas[f]!,
                    onChanged: (v) => setState(() {
                      _vagas[f] = v;
                      _preview = null;
                    }),
                  ),
              ListRow(
                title: 'Santa Ceia no 1º domingo',
                trailing: AppSwitch(
                  value: _ceiaPrimeiroDomingo,
                  onChanged: (v) => setState(() {
                    _ceiaPrimeiroDomingo = v;
                    _preview = null;
                  }),
                ),
              ),
              if (_ceiaPrimeiroDomingo)
                _Stepper(
                  icon: FuncaoDiaconal.ceia.icon,
                  color: FuncaoDiaconal.ceia.color(pal),
                  label: 'Santa Ceia',
                  value: _ceia,
                  onChanged: (v) => setState(() {
                    _ceia = v;
                    _preview = null;
                  }),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: PrimaryButton(
              label: _preview == null ? 'Gerar prévia' : 'Gerar de novo',
              icon: CupertinoIcons.wand_stars,
              onPressed: _gerar,
            ),
          ),
        ),
        if (_preview != null) ...[
          if (_preview!.vagas.isNotEmpty)
            SliverToBoxAdapter(
              child: NoticeCard(
                icon: CupertinoIcons.exclamationmark_triangle_fill,
                title: 'Faltou gente em ${_preview!.vagas.length} vaga(s)',
                message: _preview!.vagas
                    .take(4)
                    .map((v) => '${fmtDate(v.$1.split('|').first).substring(0, 5)} ${v.$2.label}: faltou ${v.$3}')
                    .join('\n'),
                color: pal.orange,
              ),
            ),
          for (final e in _drafts)
            SliverToBoxAdapter(
              child: Section(
                header: '${capitalize(fmtShortDate(e.date))} · ${e.time}',
                children: [
                  ListRow(title: e.title, subtitle: '${e.people.length} pessoas'),
                  for (final f in FuncaoDiaconal.values)
                    if ((e.assignments[f] ?? const []).isNotEmpty)
                      ListRow(
                        leading: IconTile(f.icon, color: f.color(pal), size: 28),
                        title: f.label,
                        subtitle: e.assignments[f]!.map((id) => e.names[id] ?? '?').join(', '),
                      ),
                ],
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'Publicar ${_drafts.length} escalas',
                    loading: _saving,
                    onPressed: () => _salvar(true),
                  ),
                  const SizedBox(height: 10),
                  TintButton(
                    label: 'Salvar como rascunho',
                    large: true,
                    expand: true,
                    onPressed: _saving ? null : () => _salvar(false),
                  ),
                  const SizedBox(height: 8),
                  Text('Depois dá para trocar qualquer pessoa em cada culto.', style: context.text.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => ListRow(
    leading: IconTile(icon, color: color, size: 28),
    title: label,
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: value == 0 ? null : () => onChanged(value - 1),
          icon: const Icon(CupertinoIcons.minus_circle),
        ),
        SizedBox(
          width: 22,
          child: Text('$value', textAlign: TextAlign.center, style: context.text.titleMedium),
        ),
        IconButton(
          onPressed: value >= 10 ? null : () => onChanged(value + 1),
          icon: const Icon(CupertinoIcons.plus_circle),
        ),
      ],
    ),
  );
}
