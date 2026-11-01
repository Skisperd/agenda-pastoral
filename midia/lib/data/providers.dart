import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_service.dart';
import 'modelos.dart';
import 'repositorio.dart';
import 'store/doc_store.dart';

// Sobrescritos em main.dart (Firebase ou demonstração).
final isDemoProvider = Provider<bool>((_) => false);
final docStoreProvider = Provider<DocStore>((_) => throw UnimplementedError());
final authServiceProvider = Provider<AuthService>((_) => throw UnimplementedError());

final repoProvider = Provider<Repositorio>((ref) => Repositorio(ref.watch(docStoreProvider)));
final authStateProvider = StreamProvider<AuthUser?>((ref) => ref.watch(authServiceProvider).authStateChanges());

final usuarioProvider = StreamProvider<Usuario?>((ref) async* {
  final a = await ref.watch(authStateProvider.future);
  if (a == null) {
    yield null;
    return;
  }
  final repo = ref.watch(repoProvider);
  await repo.garantirUsuario(a);
  yield* repo.watchUsuario(a.uid);
});

final acessoProvider = Provider<bool>((ref) => ref.watch(usuarioProvider).value?.acesso ?? false);
final comandaProvider = Provider<bool>((ref) => ref.watch(usuarioProvider).value?.comanda ?? false);

final estadoProvider = StreamProvider<EstadoMidia>((ref) {
  if (!ref.watch(acessoProvider)) return Stream.value(const EstadoMidia());
  return ref.watch(repoProvider).watchEstado();
});
final previaProvider = StreamProvider<(String?, String?)>((ref) {
  if (!ref.watch(acessoProvider)) return Stream.value((null, null));
  return ref.watch(repoProvider).watchPrevia();
});
final configProvider = StreamProvider<ConfigMidia>((ref) {
  if (!ref.watch(acessoProvider)) return Stream.value(const ConfigMidia());
  return ref.watch(repoProvider).watchConfig();
});
final mensagensProvider = StreamProvider<List<Mensagem>>((ref) {
  if (!ref.watch(acessoProvider)) return Stream.value(const []);
  return ref.watch(repoProvider).watchMensagens();
});
final meusComandosProvider = StreamProvider<List<Comando>>((ref) {
  final u = ref.watch(usuarioProvider).value;
  if (u == null || !u.comanda) return Stream.value(const []);
  return ref.watch(repoProvider).watchMeusComandos(u.uid);
});

/// Relógio que atualiza a cada segundo (tempo de transmissão, ponte online).
final agoraProvider = StreamProvider<DateTime>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
);
