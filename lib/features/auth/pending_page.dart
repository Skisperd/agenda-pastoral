import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../data/providers.dart';

class PendingPage extends ConsumerWidget {
  const PendingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
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
                      : 'Quase lá, ${(user.value?.name ?? '').split(' ').first}',
                  message: user.hasError
                      ? '${user.error}'
                      : 'A secretaria ou o pastor precisa liberar seu acesso e definir seu perfil. '
                            'Esta tela atualiza sozinha.',
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
