import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../features/ajustes_page.dart';
import '../features/ao_vivo_page.dart';
import '../features/camera_page.dart';
import '../features/comandar_page.dart';
import '../features/login_page.dart';
import '../features/mensagens_page.dart';
import '../features/pending_page.dart';
import '../features/shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref
    ..listen(authStateProvider, (_, _) => refresh.value++)
    ..listen(usuarioProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final user = ref.read(usuarioProvider);
      final loc = state.matchedLocation;
      const abertas = {'/login', '/aguardando', '/carregando'};
      if (auth.isLoading && !auth.hasValue) return '/carregando';
      if (auth.value == null) return loc == '/login' ? null : '/login';
      if (!user.hasValue) return user.hasError ? '/aguardando' : '/carregando';
      if (!(user.value?.acesso ?? false)) return loc == '/aguardando' ? null : '/aguardando';
      if (abertas.contains(loc)) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/aguardando', builder: (_, _) => const PendingPage()),
      GoRoute(
        path: '/carregando',
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const AoVivoPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/camera', builder: (_, _) => const CameraPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/mensagens', builder: (_, _) => const MensagensPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/comandar', builder: (_, _) => const ComandarPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/ajustes', builder: (_, _) => const AjustesPage())],
          ),
        ],
      ),
    ],
  );
});
