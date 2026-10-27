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

import 'core/error_reporting.dart';
import 'core/platform/safe_area.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/auth/auth_service.dart';
import 'data/demo_seed.dart';
import 'data/geocoder.dart';
import 'data/providers.dart';
import 'data/store/firestore_doc_store.dart';
import 'data/store/memory_doc_store.dart';
import 'firebase_options.dart';

/// `--dart-define=DEMO=true` força o modo demonstração mesmo com Firebase.
const _forceDemo = bool.fromEnvironment('DEMO');

/// `--dart-define=EMULATOR=true` usa os emuladores locais do Firebase.
const _useEmulator = bool.fromEnvironment('EMULATOR');

/// Endereço dos emuladores (no emulador Android: 10.0.2.2).
const _emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');

  final overrides = await (_forceDemo
      ? demoOverrides()
      : _firebaseOverrides().catchError((Object e) {
          debugPrint('Firebase indisponível ($e) — iniciando em modo demonstração.');
          return demoOverrides();
        }));

  runApp(ProviderScope(overrides: overrides, child: const IgrejaApp()));
}

Future<List<Override>> _firebaseOverrides() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final db = FirebaseFirestore.instance;
  // Cache offline: a agenda e os contatos abrem mesmo sem sinal.
  db.settings = const Settings(persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
  if (_useEmulator) {
    db.useFirestoreEmulator(_emulatorHost, 8080);
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
  }
  return [
    docStoreProvider.overrideWithValue(FirestoreDocStore(db)),
    authServiceProvider.overrideWithValue(FirebaseAuthService(FirebaseAuth.instance)),
  ];
}

/// Modo demonstração: dados de exemplo em memória e escolha do perfil na entrada.
Future<List<Override>> demoOverrides() async {
  final store = MemoryDocStore();
  await seedDemo(store, DateTime.now());
  return [
    isDemoProvider.overrideWithValue(true),
    docStoreProvider.overrideWithValue(store),
    authServiceProvider.overrideWithValue(DemoAuthService()),
    geocoderProvider.overrideWithValue(DemoGeocoder()),
  ];
}

class IgrejaApp extends ConsumerStatefulWidget {
  const IgrejaApp({super.key});

  @override
  ConsumerState<IgrejaApp> createState() => _IgrejaAppState();
}

class _IgrejaAppState extends ConsumerState<IgrejaApp> {
  @override
  void initState() {
    super.initState();
    // Erros não tratados vão para errorLogs (não no modo demonstração nem em debug).
    if (!ref.read(isDemoProvider) && !kDebugMode) {
      ErrorReporter(ref.read(docStoreProvider), uid: () => ref.read(authStateProvider).value?.uid).install();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Pedras Vivas',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: ThemeMode.light,
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
