import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/providers.dart';
import '../features/admin/igreja_page.dart';
import '../features/admin/users_page.dart';
import '../features/agenda/agenda_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/pending_page.dart';
import '../features/avisos/avisos_page.dart';
import '../features/escala/escala_detail_page.dart';
import '../features/escala/escala_gerar_page.dart';
import '../features/escala/escala_page.dart';
import '../features/eventos/evento_detail_page.dart';
import '../features/eventos/evento_form_page.dart';
import '../features/home/home_page.dart';
import '../features/mais_page.dart';
import '../features/oracao/oracao_page.dart';
import '../features/pastoral/pastoral_page.dart';
import '../features/perfil/meu_cadastro_page.dart';
import '../features/pessoas/membro_detail_page.dart';
import '../features/pessoas/membro_form_page.dart';
import '../features/pessoas/pessoas_page.dart';
import '../features/shell.dart';
import '../features/videos/videos_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Reavalia o redirect sempre que login/perfil mudarem.
  final refresh = ValueNotifier(0);
  ref
    ..listen(authStateProvider, (_, _) => refresh.value++)
    ..listen(currentUserProvider, (_, _) => refresh.value++)
    ..onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final user = ref.read(currentUserProvider);
      final loc = state.matchedLocation;
      const open = {'/login', '/aguardando', '/carregando'};

      if (auth.isLoading && !auth.hasValue) return '/carregando';
      if (auth.value == null) return loc == '/login' ? null : '/login';
      if (!user.hasValue) return user.hasError ? '/aguardando' : '/carregando';
      final role = user.value?.role;
      if (role == null || !role.isApproved) return loc == '/aguardando' ? null : '/aguardando';
      if (open.contains(loc)) return '/';
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
            routes: [GoRoute(path: '/', builder: (_, _) => const HomePage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/agenda',
                builder: (_, s) => AgendaPage(initialTab: s.uri.queryParameters['aba']),
                routes: [
                  GoRoute(path: 'evento/novo', builder: (_, _) => const EventoFormPage()),
                  GoRoute(
                    path: 'evento/:id',
                    builder: (_, s) => EventoDetailPage(id: s.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'editar',
                        builder: (_, s) => EventoFormPage(id: s.pathParameters['id']),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/pastoral', builder: (_, _) => const PastoralPage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pessoas',
                builder: (_, _) => const PessoasPage(),
                routes: [
                  GoRoute(path: 'novo', builder: (_, _) => const MembroFormPage()),
                  GoRoute(
                    path: ':id',
                    builder: (_, s) => MembroDetailPage(id: s.pathParameters['id']!),
                    routes: [
                      GoRoute(
                        path: 'editar',
                        builder: (_, s) => MembroFormPage(id: s.pathParameters['id']),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mais',
                builder: (_, _) => const MaisPage(),
                routes: [
                  GoRoute(
                    path: 'escala',
                    builder: (_, _) => const EscalaPage(),
                    routes: [
                      GoRoute(path: 'gerar', builder: (_, _) => const EscalaGerarPage()),
                      GoRoute(
                        path: ':id',
                        builder: (_, s) => EscalaDetailPage(id: s.pathParameters['id']!),
                      ),
                    ],
                  ),
                  GoRoute(path: 'videos', builder: (_, _) => const VideosPage()),
                  GoRoute(path: 'avisos', builder: (_, _) => const AvisosPage()),
                  GoRoute(path: 'oracao', builder: (_, _) => const OracaoPage()),
                  GoRoute(path: 'cadastro', builder: (_, _) => const MeuCadastroPage()),
                  GoRoute(path: 'usuarios', builder: (_, _) => const UsersPage()),
                  GoRoute(path: 'igreja', builder: (_, _) => const IgrejaPage()),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
