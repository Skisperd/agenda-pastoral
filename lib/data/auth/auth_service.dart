import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/roles.dart';

class AuthUser {
  const AuthUser({required this.uid, required this.email, required this.name});
  final String uid;
  final String email;
  final String name;
}

abstract class AuthService {
  Stream<AuthUser?> authStateChanges();
  Future<void> signInWithEmail(String email, String password);
  Future<void> signUpWithEmail(String name, String email, String password);
  Future<void> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);
  final FirebaseAuth _auth;

  AuthUser? _map(User? u) => u == null
      ? null
      : AuthUser(uid: u.uid, email: u.email ?? '', name: u.displayName ?? u.email?.split('@').first ?? '');

  @override
  Stream<AuthUser?> authStateChanges() => _auth.userChanges().map(_map);

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  @override
  Future<void> signUpWithEmail(String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await cred.user?.updateDisplayName(name.trim());
    await cred.user?.reload();
  }

  @override
  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
    } else {
      await _auth.signInWithProvider(provider);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  @override
  Future<void> signOut() => _auth.signOut();
}

/// Login de faz-de-conta: escolhe-se o perfil na tela de entrada.
class DemoAuthService implements AuthService {
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  static String uidFor(AppRole role) => 'demo-${role.name}';

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  void signInAs(AppRole role) {
    _current = AuthUser(uid: uidFor(role), email: '${role.name}@demo.icppv', name: 'Demo · ${role.label}');
    _controller.add(_current);
  }

  @override
  Future<void> signInWithEmail(String email, String password) async => signInAs(AppRole.admin);

  @override
  Future<void> signUpWithEmail(String name, String email, String password) async => signInAs(AppRole.admin);

  @override
  Future<void> signInWithGoogle() async => signInAs(AppRole.admin);

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }
}

/// Mensagens de erro do Firebase Auth em português.
String authErrorMessage(Object e) {
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'invalid-email' => 'E-mail inválido.',
      'user-disabled' => 'Conta desativada.',
      'user-not-found' || 'wrong-password' || 'invalid-credential' => 'E-mail ou senha incorretos.',
      'email-already-in-use' => 'Já existe uma conta com este e-mail.',
      'weak-password' => 'Senha fraca: use pelo menos 6 caracteres.',
      'popup-closed-by-user' || 'web-context-canceled' => 'Login cancelado.',
      'network-request-failed' => 'Sem conexão com a internet.',
      'operation-not-allowed' =>
        'Esta forma de login ainda não foi ativada no Firebase (Authentication › Método de login).',
      'unauthorized-domain' =>
        'Este site ainda não está autorizado no Firebase (Authentication › Configurações › Domínios autorizados).',
      _ => e.message ?? e.code,
    };
  }
  return e.toString();
}
