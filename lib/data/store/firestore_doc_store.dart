import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'doc_store.dart';

const _logSync = bool.fromEnvironment('EMULATOR');

class FirestoreDocStore implements DocStore {
  FirestoreDocStore(this._db);
  final FirebaseFirestore _db;

  @override
  Stream<List<Doc>> watchCollection(String path) =>
      _db.collection(path).snapshots().map((s) => [for (final d in s.docs) Doc(d.id, _plain(d.data()))]);

  @override
  Stream<List<Doc>> watchSynced(String path) {
    final docs = <String, Doc>{};
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
    // Controller de uma assinatura só: fechado no onCancel, junto com a escuta do Firestore.
    // ignore: close_sinks
    late final StreamController<List<Doc>> ctrl;
    List<Doc> visible() => [
      for (final d in docs.values)
        if (d.data['deleted'] != true) d,
    ];

    ctrl = StreamController<List<Doc>>(
      onListen: () async {
        final key = 'sync:$path';
        SharedPreferences? prefs;
        var since = '';
        try {
          prefs = await SharedPreferences.getInstance();
          // Marcador gravado só após uma sincronização completa: "<maior updatedAt>|<qtde>"
          final marker = prefs.getString(key)?.split('|');
          if (marker != null && marker.length == 2) {
            final cached = await _db.collection(path).get(const GetOptions(source: Source.cache));
            // Cópia local incompleta (cache limpo pelo navegador, p.ex.) → baixa tudo de novo.
            if (cached.docs.length >= (int.tryParse(marker[1]) ?? 1 << 30)) {
              for (final d in cached.docs) {
                docs[d.id] = Doc(d.id, _plain(d.data()));
              }
              since = marker[0];
            }
          }
        } catch (_) {
          docs.clear();
          since = '';
        }
        if (docs.isNotEmpty) ctrl.add(visible());

        Query<Map<String, dynamic>> q = _db.collection(path);
        if (since.isNotEmpty) q = q.where('updatedAt', isGreaterThan: since);
        sub = q.snapshots().listen((s) {
          for (final ch in s.docChanges) {
            if (ch.type == DocumentChangeType.removed) continue; // sai da consulta, mas segue válido localmente
            docs[ch.doc.id] = Doc(ch.doc.id, _plain(ch.doc.data()!));
          }
          if (_logSync) {
            debugPrint(
              '[sync] $path: ${s.docChanges.length} do ${s.metadata.isFromCache ? 'cache' : 'servidor'}'
              '${since.isEmpty ? ' (completa)' : ' (desde $since)'}',
            );
          }
          if (!s.metadata.isFromCache) {
            final newest = docs.values
                .map((d) => d.data['updatedAt'])
                .whereType<String>()
                .fold('', (a, b) => b.compareTo(a) > 0 ? b : a);
            prefs?.setString(key, '$newest|${docs.length}');
          }
          ctrl.add(visible());
        }, onError: ctrl.addError);
      },
      onCancel: () async {
        await sub?.cancel();
        await ctrl.close();
      },
    );
    return ctrl.stream;
  }

  @override
  Stream<Doc?> watchDoc(String path) =>
      _db.doc(path).snapshots().map((d) => d.exists ? Doc(d.id, _plain(d.data()!)) : null);

  @override
  Stream<List<Doc>> watchWhere(String path, String field, List<Object> values) => _db
      .collection(path)
      .where(field, whereIn: values)
      .snapshots()
      .map((s) => [for (final d in s.docs) Doc(d.id, _plain(d.data()))]);

  @override
  Future<Doc?> getDoc(String path) async {
    final d = await _db.doc(path).get();
    return d.exists ? Doc(d.id, _plain(d.data()!)) : null;
  }

  @override
  Future<void> set(String path, Map<String, dynamic> data, {bool merge = false}) =>
      _db.doc(path).set(data, SetOptions(merge: merge));

  @override
  Future<String> add(String collectionPath, Map<String, dynamic> data) async =>
      (await _db.collection(collectionPath).add(data)).id;

  @override
  Future<void> delete(String path) => _db.doc(path).delete();

  @override
  Future<void> batch(List<DocWrite> writes) async {
    final b = _db.batch();
    for (final w in writes) {
      b.set(_db.doc(w.path), w.data, SetOptions(merge: w.merge));
    }
    await b.commit();
  }

  @override
  Future<void> transact(
    List<String> paths,
    List<DocWrite> Function(Map<String, Map<String, dynamic>?> current) build,
  ) => _db.runTransaction((tx) async {
    final current = <String, Map<String, dynamic>?>{};
    for (final p in paths) {
      final d = await tx.get(_db.doc(p));
      current[p] = d.exists ? _plain(d.data()!) : null;
    }
    for (final w in build(current)) {
      tx.set(_db.doc(w.path), w.data, SetOptions(merge: w.merge));
    }
  });

  /// Converte Timestamps (caso alguém edite pelo console) em ISO-8601,
  /// formato usado pelo app em todos os campos de data.
  static Map<String, dynamic> _plain(Map<String, dynamic> m) => m.map((k, v) => MapEntry(k, _value(v)));

  static dynamic _value(dynamic v) => switch (v) {
    final Timestamp t => t.toDate().toUtc().toIso8601String(),
    final Map<String, dynamic> m => _plain(m),
    final List<dynamic> l => l.map(_value).toList(),
    _ => v,
  };
}
