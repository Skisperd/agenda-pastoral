import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/roles.dart';
import '../../core/widgets.dart';
import '../../data/models/people.dart';
import '../../data/providers.dart';

class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    if (!(me?.role.canManageUsers ?? false)) {
      return const AppScaffold(
        maxWidth: kFormWidth,
        title: 'Usuários',
        large: false,
        slivers: [
          SliverToBoxAdapter(
            child: EmptyState(icon: CupertinoIcons.lock, title: 'Sem permissão'),
          ),
        ],
      );
    }
    final memberMap = ref.watch(memberMapProvider);

    return AppScaffold(
      maxWidth: kFormWidth,
      title: 'Usuários',
      previousPageTitle: 'Mais',
      slivers: [
        SliverToBoxAdapter(
          child: AsyncView(
            ref.watch(usersProvider),
            builder: (users) {
              final pending = users.where((u) => u.role == AppRole.pending).toList();
              final others = users.where((u) => u.role != AppRole.pending).toList();
              Widget row(AppUser u) => ListRow(
                leading: IconTile(u.role.symbol, color: u.role.tint),
                title: u.name.isEmpty ? u.email : u.name,
                subtitle: [
                  u.role.label,
                  u.memberId == null ? 'sem cadastro vinculado' : 'cadastro: ${memberMap[u.memberId]?.name ?? '?'}',
                ].join(' · '),
                value: u.uid == me!.uid ? 'Você' : null,
                onTap: u.uid == me.uid ? null : () => _edit(context, ref, u),
              );
              return Column(
                children: [
                  if (pending.isNotEmpty)
                    Section(
                      header: 'Aguardando aprovação',
                      footer: 'Toque para liberar o acesso e escolher o perfil.',
                      children: [for (final u in pending) row(u)],
                    ),
                  Section(header: 'Com acesso', children: [for (final u in others) row(u)]),
                  Section(
                    header: 'Perfis',
                    children: [
                      for (final (r, d) in const [
                        (AppRole.admin, 'Secretaria: tudo, inclusive usuários e cadastro de membros.'),
                        (AppRole.pastor, 'Agenda pastoral, membros, anotações pastorais, eventos e escala.'),
                        (AppRole.presbitero, 'Membros, eventos, programação, avisos e vídeos.'),
                        (AppRole.liderDiaconia, 'Monta e publica a escala diaconal.'),
                        (AppRole.diacono, 'Vê a escala, confirma presença e avisa quando não pode.'),
                        (AppRole.membro, 'Agenda, eventos e inscrições, vídeos, contatos, visita pastoral e oração.'),
                      ])
                        ListRow(
                          leading: IconTile(r.symbol, color: r.tint),
                          title: r.label,
                          subtitle: d,
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, AppUser u) async {
    var role = u.role;
    String? memberId = u.memberId;
    var q = '';
    final members = ref.read(membersProvider).value ?? const <Membro>[];
    final result = await showSheet<String>(
      context,
      tall: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) {
          final pal = c.pal;
          Widget check(bool on) => Opacity(
            opacity: on ? 1 : 0,
            child: Icon(CupertinoIcons.checkmark_alt, color: pal.accent, size: 22),
          );
          return Column(
            children: [
              SheetHeader(
                title: u.name.isEmpty ? u.email : u.name,
                action: 'Salvar',
                onAction: () => Navigator.pop(c, 'salvar'),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    Section(
                      header: 'Perfil',
                      children: [
                        for (final r in AppRole.values)
                          ListRow(
                            leading: IconTile(r.symbol, color: r.tint),
                            title: r.label,
                            trailing: check(role == r),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setS(() => role = r);
                            },
                          ),
                      ],
                    ),
                    Section(
                      header: 'Cadastro de membro',
                      footer: 'Vincular libera "Meu cadastro", a visita pastoral e "Minha escala" para esta pessoa.',
                      children: [
                        ListRow(
                          title: 'Nenhum',
                          trailing: check(memberId == null),
                          onTap: () => setS(() => memberId = null),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: SearchField(placeholder: 'Buscar nome', onChanged: (v) => setS(() => q = v)),
                        ),
                        for (final m in members)
                          if (memberId == m.id || (q.isNotEmpty && fold(m.name).contains(fold(q))))
                            ListRow(
                              title: m.name,
                              trailing: check(memberId == m.id),
                              onTap: () => setS(() => memberId = m.id),
                            ),
                      ],
                    ),
                    Section(
                      children: [
                        ListRow(
                          title: 'Remover acesso',
                          destructive: true,
                          center: true,
                          onTap: () => Navigator.pop(c, 'remover'),
                        ),
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
    if (!context.mounted) return;
    final repo = ref.read(repoProvider);
    if (result == 'salvar') {
      await guard(
        context,
        () => repo.updateUser(u.uid, role: role, memberId: memberId, clearMember: memberId == null),
        success: 'Usuário atualizado',
      );
    } else if (result == 'remover' &&
        await confirm(
          context,
          'Remover acesso?',
          message: '${u.email} precisará se cadastrar de novo.',
          ok: 'Remover',
          destructive: true,
        ) &&
        context.mounted) {
      await guard(context, () => repo.deleteUser(u.uid), success: 'Acesso removido');
    }
  }
}
