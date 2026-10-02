// Configuração do projeto Firebase "agenda-pastoral-15bff".
//
// Estes valores identificam o projeto e não são segredos: a proteção dos
// dados fica nas regras do Firestore (firestore.rules). Para gerar as
// configurações de Android e iOS, rode `flutterfire configure`, que
// substitui este arquivo.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'Firebase ainda não configurado para esta plataforma. Rode `flutterfire configure`.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAkQXbqKT_eyWumMXNKgA10HATZCWw-7m0',
    appId: '1:41433198968:web:6461637d861b1c0cc8988d',
    messagingSenderId: '41433198968',
    projectId: 'agenda-pastoral-15bff',
    authDomain: 'agenda-pastoral-15bff.firebaseapp.com',
    storageBucket: 'agenda-pastoral-15bff.firebasestorage.app',
    measurementId: 'G-05385H0T9X',
  );
}
