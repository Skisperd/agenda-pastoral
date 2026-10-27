import 'dart:async';
import 'dart:math';

import 'doc_store.dart';

/// Armazenamento em memória usado no modo demonstração. Os dados se perdem ao
/// recarregar o app.
class MemoryDocStore implements DocStore {
  final _collections = <String, Map<String, Map<String, dynamic>>>{};
  final _changes = StreamController<String>.broadcast();
  final _rand = Random();

  (String, String) _split(String docPath) {
    final i = docPath.lastIndexOf('/');
    return (docPath.substring(0, i), docPath.substring(i + 1));
  }

  List<Doc> _list(String path) => [
    for (final e in (_collections[path] ?? const {}).entries) Doc(e.key, Map<String, dynamic>.of(e.value)),
  ];

  Doc? _get(String docPath) {
    final (col, id) = _split(docPath);
    final data = _collections[col]?[id];
    return data == null ? null : Doc(id, Map<String, dynamic>.of(data));
  }

  void _write(String docPath, Map<String, dynamic> data, bool merge) {
    final (col, id) = _split(docPath);
    final c = _collections.putIfAbsent(col, () => {});
    c[id] = merge ? {...?c[id], ...data} : Map<String, dynamic>.of(data);
  }

  @override
  Stream<List<Doc>> watchCollection(String path) async* {
    yield _list(path);
    await for (final changed in _changes.stream) {
      if (changed == path) yield _list(path);
    }
  }

  @override
  Stream<List<Doc>> watchSynced(String path) => watchCollection(path).map(
    (docs) => [
      for (final d in docs)
        if (d.data['deleted'] != true) d,
    ],
  );

  @override
  Stream<Doc?> watchDoc(String path) async* {
    final (col, _) = _split(path);
    yield _get(path);
    await for (final changed in _changes.stream) {
      if (changed == col) yield _get(path);
    }
  }

  @override
  Stream<List<Doc>> watchWhere(String path, String field, List<Object> values) => watchCollection(path).map(
    (docs) => [
      for (final d in docs)
        if (values.contains(d.data[field])) d,
    ],
  );

  @override
  Future<Doc?> getDoc(String path) async => _get(path);

  @override
  Future<void> set(String path, Map<String, dynamic> data, {bool merge = false}) async {
    _write(path, data, merge);
    _changes.add(_split(path).$1);
  }

  @override
  Future<String> add(String collectionPath, Map<String, dynamic> data) async {
    final id = List.generate(20, (_) => _rand.nextInt(36).toRadixString(36)).join();
    await set('$collectionPath/$id', data);
    return id;
  }

  @override
  Future<void> delete(String path) async {
    final (col, id) = _split(path);
    _collections[col]?.remove(id);
    _changes.add(col);
  }

  @override
  Future<void> batch(List<DocWrite> writes) async {
    final touched = <String>{};
    for (final w in writes) {
      _write(w.path, w.data, w.merge);
      touched.add(_split(w.path).$1);
    }
    touched.forEach(_changes.add);
  }

  @override
  Future<void> transact(
    List<String> paths,
    List<DocWrite> Function(Map<String, Map<String, dynamic>?> current) build,
  ) async {
    final current = {for (final p in paths) p: _get(p)?.data};
    await batch(build(current));
  }
}
