import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/links.dart';
import '../core/roles.dart';
import '../core/widgets.dart';
import '../data/models/conteudo.dart';
import '../data/models/people.dart';
import '../data/providers.dart';

/// Menu com as demais áreas, o perfil e a administração.
class MaisPage extends ConsumerWidget {
  const MaisPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final role = ref.watch(roleProvider);
    final igreja = ref.watch(igrejaProvider).value ?? const IgrejaConfig();
    final pal = context.pal;
    final pendentes = role.canManageUsers
        ? (ref.watch(usersProvider).value ?? const <AppUser>[]).where((u) => u.role == AppRole.pending).length
        : 0;
    final minhasEscalas = ref.watch(myEscalasProvider).length;
    return AppScaffold(
      title: 'Mais',
      slivers: [
        if (user != null)
          SliverToBoxAdapter(
            child: Section(
              children: [
                ListRow(
                  leading: Initials(user.name, size: 52),
                  titleWidget: Text(user.name, style: context.text.titleMedium),
                  subtitle: '${user.role.label} · ${user.email}',
                  onTap: () => context.go('/mais/cadastro'),
                ),
              ],
            ),
          ),
        SliverToBoxAdapter(
          child: Section(
            header: 'Igreja',
            children: [
              ListRow(
                leading: IconTile(CupertinoIcons.person_3_fill, color: pal.green),
                title: 'Escala diaconal',
                value: minhasEscalas > 0 ? '$minhasEscalas minha(s)' : null,
                onTap: () => context.go('/mais/escala'),
              ),
              ListRow(
                leading: IconTile(CupertinoIcons.play_rectangle_fill, color: pal.red),
                title: 'Vídeos',
                onTap: () => context.go('/mais/videos'),
              ),
              ListRow(
                leading: IconTile(CupertinoIcons.news_solid, color: pal.orange),
                title: 'Avisos',
                onTap: () => context.go('/mais/avisos'),
              ),
              ListRow(
                leading: IconTile(CupertinoIcons.heart_circle_fill, color: pal.purple),
                title: 'Pedidos de oração',
                onTap: () => context.go('/mais/oracao'),
              ),
              if (igreja.pix != null)
                ListRow(
                  leading: const IconTile(CupertinoIcons.gift_fill, color: Brand.navy),
                  title: 'Dízimos e ofertas (PIX)',
                  subtitle: igreja.pix,
                  value: 'Copiar',
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: igreja.pix!));
                    if (context.mounted) toast(context, 'Chave PIX copiada');
                  },
                ),
              if (igreja.instagram != null)
                ListRow(
                  leading: IconTile(CupertinoIcons.camera_fill, color: pal.pink),
                  title: 'Instagram',
                  onTap: () => openUrl(context, igreja.instagram!),
                ),
              if (igreja.site != null)
                ListRow(
                  leading: const IconTile(CupertinoIcons.globe, color: Brand.blue),
                  title: 'Site da igreja',
                  onTap: () => openUrl(context, igreja.site!),
                ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Section(
            header: 'Você',
            children: [
              ListRow(
                leading: const IconTile(CupertinoIcons.person_crop_circle_fill, color: Brand.blue),
                title: 'Meu cadastro',
                onTap: () => context.go('/mais/cadastro'),
              ),
              ListRow(
                leading: IconTile(CupertinoIcons.square_arrow_left, color: pal.gray),
                title: 'Sair',
                onTap: () async {
                  if (await confirm(context, 'Sair da conta?', ok: 'Sair') && context.mounted) {
                    await ref.read(authServiceProvider).signOut();
                  }
                },
              ),
            ],
          ),
        ),
        if (role.canManageUsers || role.isLeader)
          SliverToBoxAdapter(
            child: Section(
              header: 'Administração',
              children: [
                if (role.canManageUsers)
                  ListRow(
                    leading: const IconTile(CupertinoIcons.person_badge_plus_fill, color: Brand.navy),
                    title: 'Usuários e permissões',
                    value: pendentes > 0 ? '$pendentes aguardando' : null,
                    onTap: () => context.go('/mais/usuarios'),
                  ),
                if (role.isLeader)
                  ListRow(
                    leading: IconTile(CupertinoIcons.building_2_fill, color: pal.indigo),
                    title: 'Dados da igreja',
                    subtitle: 'Contatos, YouTube, PIX',
                    onTap: () => context.go('/mais/igreja'),
                  ),
              ],
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            child: Column(
              children: [
                const BrandMark(height: 34),
                const SizedBox(height: 8),
                Text(igreja.name, textAlign: TextAlign.center, style: context.text.bodySmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
