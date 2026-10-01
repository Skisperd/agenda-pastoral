import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'data/seed.dart';
import 'firebase/auth_gate.dart';
import 'firebase_options.dart';
import 'ui/home_page.dart';

/// `--dart-define=DEMO=true` força o modo demonstração mesmo com Firebase configurado.
const forceDemo = bool.fromEnvironment('DEMO');

/// `--dart-define=EMULATORS=true` usa os emuladores locais do Firebase
/// (`firebase emulators:start`), sem precisar de projeto real.
const useEmulators = bool.fromEnvironment('EMULATORS');

/// Host dos emuladores. No emulador Android, use 10.0.2.2.
const emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: 'localhost');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (useEmulators) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'demo-key',
        appId: '1:1:web:1',
        messagingSenderId: '1',
        projectId: 'demo-agenda',
      ),
    );
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    runApp(const AgendaApp(home: AuthGate()));
    return;
  }
  if (!forceDemo) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      runApp(const AgendaApp(home: AuthGate()));
      return;
    } on UnsupportedError catch (e) {
      debugPrint('$e Abrindo no modo demonstração.');
    }
  }
  runApp(AgendaApp(home: HomePage(store: demoStore())));
}
