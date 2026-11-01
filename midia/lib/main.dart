import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:intl/date_symbol_data_local.dart';

import 'core/platform/safe_area.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/auth/auth_service.dart';
import 'data/demo.dart';
import 'data/providers.dart';
import 'data/store/firestore_doc_store.dart';
import 'data/store/memory_doc_store.dart';
import 'firebase_options.dart';

/// `--dart-define=DEMO=true` força o modo demonstração.
const _forceDemo = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final overrides = await (_forceDemo
      ? demoOverrides()
      : _firebaseOverrides().catchError((Object e) {
          debugPrint('Firebase indisponível ($e) — modo demonstração.');
          return demoOverrides();
        }));
  runApp(ProviderScope(overrides: overrides, child: const MidiaApp()));
}

Future<List<Override>> _firebaseOverrides() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final db = FirebaseFirestore.instance;
  db.settings = const Settings(persistenceEnabled: true);
  return [
    docStoreProvider.overrideWithValue(FirestoreDocStore(db)),
    authServiceProvider.overrideWithValue(FirebaseAuthService(FirebaseAuth.instance)),
  ];
}

Future<List<Override>> demoOverrides() async {
  final store = MemoryDocStore();
  await seedDemo(store);
  PonteDemo(store).iniciar();
  return [
    isDemoProvider.overrideWithValue(true),
    docStoreProvider.overrideWithValue(store),
    authServiceProvider.overrideWithValue(DemoAuthService()),
  ];
}

class MidiaApp extends ConsumerWidget {
  const MidiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'Mídia · Pedras Vivas',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    // Cabine de mídia: escuro, para não ofuscar no culto.
    themeMode: ThemeMode.dark,
    routerConfig: ref.watch(routerProvider),
    builder: (_, child) => WebSafeArea(child: child ?? const SizedBox.shrink()),
    locale: const Locale('pt', 'BR'),
    supportedLocales: const [Locale('pt', 'BR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    scrollBehavior: const MaterialScrollBehavior().copyWith(
      dragDevices: {...const MaterialScrollBehavior().dragDevices, if (kIsWeb) PointerDeviceKind.mouse},
    ),
  );
}
