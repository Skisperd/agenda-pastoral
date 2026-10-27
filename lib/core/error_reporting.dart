import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/store/doc_store.dart';

/// Registra erros não tratados na coleção `errorLogs` do Firestore, para a liderança
/// saber o que quebrou no celular de alguém (o Crashlytics não funciona no site).
///
/// Evita ruído e custo: o mesmo erro só é enviado uma vez por sessão e no máximo
/// [maxPorSessao] erros vão para o servidor. Falhas ao registrar são ignoradas.
class ErrorReporter {
  ErrorReporter(this._store, {this.uid, this.maxPorSessao = 20, this.plataforma});

  static const colecao = 'errorLogs';

  final DocStore _store;

  /// Quem estava usando (para reproduzir o problema); nulo antes do login.
  String? Function()? uid;
  final int maxPorSessao;

  /// "web", "ios", "android"... (injetável para testes).
  final String? plataforma;

  final _vistos = <int>{};
  int _enviados = 0;

  /// Chave do erro: mensagem e primeira linha útil da pilha.
  static int chave(Object error, StackTrace? stack) {
    final primeira = (stack?.toString() ?? '').split('\n').firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    return Object.hash(error.runtimeType, error.toString(), primeira);
  }

  static String _corta(String s, int max) => s.length <= max ? s : '${s.substring(0, max)}…';

  /// Dados gravados; separado para ser testável.
  Map<String, dynamic> payload(Object error, StackTrace? stack, {String? origem}) => {
    'tipo': error.runtimeType.toString(),
    'mensagem': _corta(error.toString(), 500),
    'pilha': _corta((stack?.toString() ?? '').split('\n').take(25).join('\n'), 3000),
    'origem': ?origem,
    'plataforma': plataforma ?? (kIsWeb ? 'web' : defaultTargetPlatform.name),
    'modo': kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
    'uid': ?uid?.call(),
    'createdAt': nowIso(),
  };

  /// Envia o erro, se ainda não foi enviado nesta sessão e o limite não foi atingido.
  Future<bool> report(Object error, StackTrace? stack, {String? origem}) async {
    if (_enviados >= maxPorSessao || !_vistos.add(chave(error, stack))) return false;
    _enviados++;
    try {
      await _store.add(colecao, payload(error, stack, origem: origem));
      return true;
    } catch (_) {
      return false; // sem rede ou sem permissão: não há o que fazer
    }
  }

  /// Liga os ganchos globais do Flutter e da plataforma a este registrador.
  void install() {
    final anterior = FlutterError.onError;
    FlutterError.onError = (details) {
      anterior?.call(details);
      unawaited(report(details.exception, details.stack, origem: details.library ?? 'flutter'));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(report(error, stack, origem: 'assíncrono'));
      return true; // tratado: não derruba o app
    };
  }
}
