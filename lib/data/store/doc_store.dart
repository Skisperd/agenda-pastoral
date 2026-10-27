/// Abstração mínima de banco de documentos.
///
/// Os caminhos seguem a convenção do Firestore: coleções têm número ímpar de
/// segmentos (`services`, `services/abc/comments`) e documentos número par
/// (`services/abc`). Existem duas implementações: [FirestoreDocStore] (produção)
/// e [MemoryDocStore] (modo demonstração, sem Firebase configurado).
library;

class Doc {
  const Doc(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

class DocWrite {
  const DocWrite(this.path, this.data, {this.merge = true});
  final String path;
  final Map<String, dynamic> data;
  final bool merge;
}

abstract class DocStore {
  Stream<List<Doc>> watchCollection(String path);

  /// Coleção mantida em cópia local: emite tudo, mas só busca no servidor os
  /// documentos com `updatedAt` posterior à última sincronização. Documentos
  /// marcados com `deleted: true` não são emitidos.
  Stream<List<Doc>> watchSynced(String path);
  Stream<Doc?> watchDoc(String path);

  /// Documentos da coleção cujo campo [field] vale um dos [values]. Usado onde as
  /// regras do servidor só liberam parte da coleção (ex.: contatos da liderança).
  Stream<List<Doc>> watchWhere(String path, String field, List<Object> values);
  Future<Doc?> getDoc(String path);
  Future<void> set(String path, Map<String, dynamic> data, {bool merge = false});
  Future<String> add(String collectionPath, Map<String, dynamic> data);
  Future<void> delete(String path);

  /// Escritas atômicas (o Firestore limita a 500 por lote; quem chama divide).
  Future<void> batch(List<DocWrite> writes);

  /// Lê [paths] e grava o que [build] devolver, de forma atômica: se outro
  /// aparelho alterar algum desses documentos no meio, tudo é refeito.
  /// [build] pode lançar uma exceção para desistir (nada é gravado).
  Future<void> transact(List<String> paths, List<DocWrite> Function(Map<String, Map<String, dynamic>?> current) build);
}

String nowIso() => DateTime.now().toUtc().toIso8601String();
