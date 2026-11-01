import 'auth/auth_service.dart';
import 'modelos.dart';
import 'store/doc_store.dart';

abstract final class Col {
  static const users = 'users';
  static const estado = 'midia/estado';
  static const previa = 'midia/previa';
  static const config = 'midia/config';
  static const comandos = 'midiaComandos';
  static const mensagens = 'midiaMensagens';
}

class Repositorio {
  Repositorio(this.store);
  final DocStore store;

  Stream<Usuario?> watchUsuario(String uid) =>
      store.watchDoc('${Col.users}/$uid').map((d) => d == null ? null : Usuario.fromMap(d.id, d.data));

  /// Quem entra pela primeira vez por aqui fica a aguardar aprovação, como no app da igreja.
  Future<void> garantirUsuario(AuthUser a) async {
    if (await store.getDoc('${Col.users}/${a.uid}') != null) return;
    await store.set('${Col.users}/${a.uid}', {
      'name': a.name,
      'email': a.email,
      'role': 'pending',
      'createdAt': nowIso(),
    });
  }

  Stream<EstadoMidia> watchEstado() => store.watchDoc(Col.estado).map((d) => EstadoMidia.fromMap(d?.data));

  /// Miniatura do programa (data URL JPEG) e quando foi tirada.
  Stream<(String?, String?)> watchPrevia() =>
      store.watchDoc(Col.previa).map((d) => (d?.data['programa'] as String?, d?.data['em'] as String?));

  Stream<ConfigMidia> watchConfig() => store.watchDoc(Col.config).map((d) => ConfigMidia.fromMap(d?.data));

  Future<void> salvarConfig(ConfigMidia c) => store.set(Col.config, c.toMap());

  Future<String> enviarComando(Usuario u, String tipo, [String? valor]) => store.add(Col.comandos, {
    'tipo': tipo,
    'valor': valor,
    'uid': u.uid,
    'nome': u.nome,
    'status': 'pendente',
    'createdAt': nowIso(),
  });

  Stream<List<Comando>> watchMeusComandos(String uid) => store
      .watchWhere(Col.comandos, 'uid', [uid])
      .map(
        (docs) => ([
          for (final d in docs) Comando.fromMap(d.id, d.data),
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt))).take(8).toList(),
      );

  Stream<List<Mensagem>> watchMensagens() => store
      .watchRecent(Col.mensagens, 'createdAt', 80)
      .map((docs) => [for (final d in docs) Mensagem.fromMap(d.id, d.data)].reversed.toList());

  Future<void> enviarMensagem(Usuario u, String texto, Destino para) => store.add(Col.mensagens, {
    'texto': texto.trim(),
    'uid': u.uid,
    'nome': u.nome,
    'para': para.name,
    'createdAt': nowIso(),
  });

  Future<void> apagarMensagem(String id) => store.delete('${Col.mensagens}/$id');
}
