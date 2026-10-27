import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/roles.dart';
import '../../core/share.dart';
import '../../core/widgets.dart';
import '../../data/models/conteudo.dart';
import '../../data/models/people.dart';
import '../../data/providers.dart';
import '../common.dart';

enum _Aba { membros, contatos, aniversarios }

enum _Filtro { todos, membros, oficiais, congregados, visitantes, diaconia, inativos }

/// Membros (secretaria, pastor e conselho) e contatos da liderança (todos).
class PessoasPage extends ConsumerStatefulWidget {
  const PessoasPage({super.key});

  @override
  ConsumerState<PessoasPage> createState() => _PessoasPageState();
}

class _PessoasPageState extends ConsumerState<PessoasPage> {
  _Aba _aba = _Aba.membros;
  _Filtro _filtro = _Filtro.membros;
  String _q = '';

  bool _match(Membro m) {
    if (_q.isNotEmpty) {
      final hay = fold('${m.name} ${m.neighborhood ?? ''} ${m.family ?? ''} ${m.ministries.join(' ')}');
      if (!hay.contains(fold(_q))) return false;
    }
    return switch (_filtro) {
      _Filtro.todos => true,
      _Filtro.membros => m.situacao.isMembro,
      _Filtro.oficiais => m.oficio != null,
      _Filtro.congregados => m.situacao == Situacao.congregado,
      _Filtro.visitantes => m.situacao == Situacao.visitante,
      _Filtro.diaconia => m.servesDiaconia,
      _Filtro.inativos => m.situacao == Situacao.inativo || m.situacao == Situacao.transferido,
    };
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(roleProvider);
    final manage = role.canManageMembers;
    final aba = manage ? _aba : _Aba.contatos;
    return AppScaffold(
      title: manage ? 'Pessoas' : 'Contatos',
      actions: [
        if (manage && aba == _Aba.membros)
          NavAction(icon: CupertinoIcons.square_arrow_up, tooltip: 'Exportar lista', onPressed: _export),
        if (manage)
          NavAction(icon: CupertinoIcons.add, tooltip: 'Novo cadastro', onPressed: () => context.go('/pessoas/novo')),
      ],
      slivers: [
        if (manage)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Segmented(
                value: _aba,
                segments: const {
                  _Aba.membros: 'Membros',
                  _Aba.contatos: 'Liderança',
                  _Aba.aniversarios: 'Aniversários',
                },
                onChanged: (v) => setState(() => _aba = v),
              ),
            ),
          ),
        switch (aba) {
          _Aba.membros => _membros(),
          _Aba.contatos => const _Contatos(),
          _Aba.aniversarios => const _Aniversarios(),
        },
      ],
    );
  }

  Widget _membros() {
    final all = ref.watch(membersProvider);
    return SliverToBoxAdapter(
      child: AsyncView(
        all,
        builder: (list) {
          final shown = list.where(_match).toList();
          final membros = list.where((m) => m.situacao.isMembro).length;
          final comung = list.where((m) => m.situacao == Situacao.comungante).length;
          final novos = list.where((m) => m.selfRegistered).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SearchField(
                  placeholder: 'Nome, bairro, família, ministério',
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              const SizedBox(height: 10),
              ChipBar<_Filtro>(
                items: const {
                  _Filtro.membros: 'Membros',
                  _Filtro.oficiais: 'Oficiais',
                  _Filtro.diaconia: 'Diaconia',
                  _Filtro.congregados: 'Congregados',
                  _Filtro.visitantes: 'Visitantes',
                  _Filtro.inativos: 'Inativos',
                  _Filtro.todos: 'Todos',
                },
                selected: _filtro,
                onSelected: (v) => setState(() => _filtro = v),
              ),
              if (novos.isNotEmpty)
                NoticeCard(
                  icon: CupertinoIcons.person_badge_plus_fill,
                  title: novos.length == 1
                      ? '1 cadastro novo para conferir'
                      : '${novos.length} cadastros novos para conferir',
                  message: novos.map((m) => m.name).take(3).join(', '),
                  color: context.pal.orange,
                  onTap: () => context.go('/pessoas/${novos.first.id}'),
                ),
              Section(
                footer: '$membros membros no rol ($comung comungantes) · ${list.length} cadastros',
                children: [
                  for (final m in shown)
                    ListRow(
                      leading: Initials(m.name),
                      title: m.name,
                      subtitle: [
                        m.oficio?.label ?? m.situacao.label,
                        ?m.neighborhood?.split(' · ').first,
                        if (m.birthDate != null) '${ageOn(m.birthDate, DateTime.now())} anos',
                      ].join(' · '),
                      onTap: () => context.go('/pessoas/${m.id}'),
                    ),
                  if (shown.isEmpty) const ListRow(title: 'Ninguém encontrado'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// Lista em texto (nome, situação, telefone) para colar numa planilha ou no WhatsApp.
  void _export() {
    final list = (ref.read(membersProvider).value ?? const <Membro>[]).where(_match);
    final text = [
      'Nome;Situação;Ofício;Telefone;E-mail;Nascimento;Bairro',
      for (final m in list)
        [
          m.name,
          m.situacao.label,
          m.oficio?.label ?? '',
          fmtPhone(m.phone),
          m.email ?? '',
          m.birthDate == null ? '' : fmtDate(m.birthDate!),
          m.neighborhood ?? '',
        ].join(';'),
    ].join('\n');
    copyForWhatsApp(context, text);
  }
}

class _Contatos extends ConsumerWidget {
  const _Contatos();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final igreja = ref.watch(igrejaProvider).value ?? const IgrejaConfig();
    final manage = ref.watch(roleProvider).canManageMembers;
    return SliverToBoxAdapter(
      child: AsyncView(
        ref.watch(officersProvider),
        builder: (list) => Column(
          children: [
            for (final o in Oficio.values)
              if (list.where((m) => m.oficio == o).isNotEmpty)
                Section(
                  header: o.plural,
                  children: [
                    for (final m in list.where((m) => m.oficio == o))
                      ContactRow(m, onTap: manage ? () => context.go('/pessoas/${m.id}') : null),
                  ],
                ),
            if (list.isEmpty)
              const EmptyState(
                icon: CupertinoIcons.person_2,
                title: 'Nenhum contato ainda',
                message: 'A secretaria marca o ofício (pastor, presbítero, diácono) no cadastro de cada um.',
              ),
            if (igreja.phone != null || igreja.email != null)
              Section(
                header: 'Secretaria',
                children: [
                  ContactRow(Membro(id: '', name: igreja.shortName, phone: igreja.phone, email: igreja.email)),
                  if (igreja.address != null) ListRow(title: igreja.address!, subtitle: 'Endereço'),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Aniversarios extends ConsumerWidget {
  const _Aniversarios();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(birthdaysProvider(366));
    final today = ref.watch(todayProvider);
    final porMes = <int, List<(Membro, DateTime)>>{};
    for (final e in list) {
      porMes.putIfAbsent(e.$2.month, () => []).add(e);
    }
    return SliverToBoxAdapter(
      child: Column(
        children: [
          for (final e in porMes.entries)
            Section(
              header: capitalize(fmtMonth(e.value.first.$2)),
              children: [
                for (final (m, d) in e.value)
                  ListRow(
                    leading: SizedBox(
                      width: 36,
                      child: Text(
                        '${d.day}',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.pal.accent),
                      ),
                    ),
                    title: m.name,
                    subtitle: [
                      if (ymd(d) == ymd(today)) 'Hoje!',
                      if (ageOn(m.birthDate, d) != null) 'faz ${ageOn(m.birthDate, d)} anos',
                    ].join(' · '),
                    onTap: () => context.go('/pessoas/${m.id}'),
                  ),
              ],
            ),
          if (list.isEmpty) const EmptyState(icon: CupertinoIcons.gift, title: 'Sem datas de nascimento cadastradas'),
        ],
      ),
    );
  }
}
