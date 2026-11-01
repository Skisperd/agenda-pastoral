import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets.dart';
import '../data/providers.dart';

class PendingPage extends ConsumerWidget {
  const PendingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(usuarioProvider);
    return Scaffold(
      backgroundColor: context.pal.background,
      body: SafeArea(
        child: Center(
          child: Constrained(
            maxWidth: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon(size: 80),
                EmptyState(
                  icon: user.hasError ? CupertinoIcons.wifi_slash : CupertinoIcons.clock,
                  title: user.hasError
                      ? 'Não foi possível carregar seu perfil'
                      : 'Quase lá, ${(user.value?.nome ?? '').split(' ').first}',
                  message: user.hasError
                      ? '${user.error}'
                      : 'Este app é da equipa de mídia. Um pastor ou presbítero libera o acesso no app da '
                            'igreja (Mais › Usuários e permissões › Equipa de mídia). Esta tela atualiza sozinha.',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TintButton(
                    label: 'Sair',
                    icon: CupertinoIcons.square_arrow_left,
                    expand: true,
                    large: true,
                    onPressed: () => ref.read(authServiceProvider).signOut(),
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
