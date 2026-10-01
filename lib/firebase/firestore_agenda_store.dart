import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../data/agenda_store.dart';
import '../domain/models.dart';
import '../domain/scheduler.dart';

/// Agenda gravada no Cloud Firestore.
///
/// Coleções (ver docs/FIREBASE.md):
/// - `users/{uid}`: cadastro do membro, com `role` "member" ou "pastor"
/// - `availability/{id}`: janelas de atendimento do pastor
/// - `visits/{id}`: visitas, legíveis só pelo pastor e pelo próprio membro
/// - `agenda/{aaaa-mm-dd}`: ocupação do dia, sem nome nem endereço, usada no
///   cálculo de deslocamento e para travar a reserva numa transação
/// - `notifications/{id}`: avisos para o pastor
class FirestoreAgendaStore extends AgendaStore {
  FirestoreAgendaStore({
    required fs.FirebaseFirestore firestore,
    required this.profile,
    super.scheduler,
    super.clock,
  }) : _db = firestore {
    _listen();
  }

  final fs.FirebaseFirestore _db;
  final UserProfile profile;
  final _subscriptions = <StreamSubscription<Object?>>[];

  List<AvailabilityWindow> _windows = const [];
  List<Visit> _visits = const [];
  List<Visit> _busy = const [];
  List<PastorNotification> _notifications = const [];

  @override
  List<AvailabilityWindow> get windows => _windows;

  @override
  List<Visit> get visits => _visits;

  @override
  List<Visit> get busy => profile.isPastor ? _visits : _busy;

  @override
  List<PastorNotification> get notifications => _notifications;

  fs.CollectionReference<Map<String, dynamic>> get _availability => _db.collection('availability');
  fs.CollectionReference<Map<String, dynamic>> get _visitsRef => _db.collection('visits');
  fs.CollectionReference<Map<String, dynamic>> get _agenda => _db.collection('agenda');
  fs.CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _db.collection('notifications');

  void _listen() {
    final today = AgendaStore.dateOnly(clock());

    _subscriptions.add(
      _availability
          .where('end', isGreaterThanOrEqualTo: fs.Timestamp.fromDate(today))
          .snapshots()
          .listen((snap) {
            _windows = snap.docs.map(_windowFrom).toList()
              ..sort((a, b) => a.start.compareTo(b.start));
            notifyListeners();
          }),
    );

    final visitsQuery = profile.isPastor
        ? _visitsRef.where('start', isGreaterThanOrEqualTo: fs.Timestamp.fromDate(today))
        : _visitsRef.where('memberId', isEqualTo: profile.member.id);
    _subscriptions.add(
      visitsQuery.snapshots().listen((snap) {
        _visits = snap.docs.map(_visitFrom).toList()..sort((a, b) => a.start.compareTo(b.start));
        notifyListeners();
      }),
    );

    if (profile.isPastor) {
      _subscriptions.add(
        _notificationsRef.orderBy('createdAt', descending: true).limit(50).snapshots().listen((
          snap,
        ) {
          _notifications = snap.docs.map(_notificationFrom).toList();
          notifyListeners();
        }),
      );
    } else {
      _subscriptions.add(
        _agenda
            .where(fs.FieldPath.documentId, isGreaterThanOrEqualTo: dayKey(today))
            .snapshots()
            .listen((snap) {
              _busy = [for (final doc in snap.docs) ..._slotsOf(doc.data()).map(_busyVisitFrom)];
              notifyListeners();
            }),
      );
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  // ---- Pastor ----

  @override
  Future<void> addWindow(DateTime start, DateTime end) async {
    AgendaStore.checkWindow(start, end);
    await _availability.add({
      'start': fs.Timestamp.fromDate(start),
      'end': fs.Timestamp.fromDate(end),
    });
  }

  @override
  Future<void> removeWindow(String id) => _availability.doc(id).delete();

  @override
  Future<int> copyWeekToNext(DateTime weekStart) async {
    final source = windowsOfWeek(weekStart);
    final batch = _db.batch();
    for (final w in source) {
      batch.set(_availability.doc(), {
        'start': fs.Timestamp.fromDate(w.start.add(const Duration(days: 7))),
        'end': fs.Timestamp.fromDate(w.end.add(const Duration(days: 7))),
      });
    }
    await batch.commit();
    return source.length;
  }

  @override
  Future<void> setVisitStatus(String visitId, VisitStatus status) async {
    if (status == VisitStatus.cancelled) {
      final visit = _visits.where((v) => v.id == visitId).firstOrNull;
      if (visit != null) return _cancel(visit, notify: false);
    }
    await _visitsRef.doc(visitId).update({'status': status.name});
  }

  @override
  Future<void> markNotificationsRead() async {
    final unread = _notifications.where((n) => !n.read).toList();
    if (unread.isEmpty) return;
    final batch = _db.batch();
    for (final n in unread) {
      batch.update(_notificationsRef.doc(n.id), {'read': true});
    }
    await batch.commit();
  }

  // ---- Membro ----

  @override
  Future<Visit> book(Member member, SlotOption slot) async {
    final dayRef = _agenda.doc(dayKey(slot.start));
    final visitRef = _visitsRef.doc();
    final notificationRef = _notificationsRef.doc();

    // O motivo é devolvido em vez de lançado dentro da transação, para não
    // depender de como cada plataforma repassa exceções do handler.
    final reason = await _db.runTransaction<String?>((tx) async {
      final day = await tx.get(dayRef);
      final slots = _slotsOf(day.data());
      final reason = scheduler.blockedReason(
        member: member,
        start: slot.start,
        end: slot.end,
        visits: slots.map(_busyVisitFrom).toList(),
      );
      if (reason != null) return reason;

      tx.set(visitRef, {
        'memberId': member.id,
        'memberName': member.name,
        'memberPhone': member.phone,
        'neighborhood': member.neighborhood,
        'location': fs.GeoPoint(member.location.lat, member.location.lng),
        'start': fs.Timestamp.fromDate(slot.start),
        'end': fs.Timestamp.fromDate(slot.end),
        'status': VisitStatus.pending.name,
        'createdAt': fs.FieldValue.serverTimestamp(),
      });
      tx.set(dayRef, {
        'slots': [
          ...slots,
          {
            'visitId': visitRef.id,
            'start': fs.Timestamp.fromDate(slot.start),
            'end': fs.Timestamp.fromDate(slot.end),
            'neighborhood': member.neighborhood,
            'area': _approximate(member.location),
          },
        ],
      });
      tx.set(notificationRef, {
        'message': 'Nova visita: ${member.name} (${member.neighborhood})',
        'createdAt': fs.FieldValue.serverTimestamp(),
        'read': false,
      });
      return null;
    });
    if (reason != null) throw StateError(reason);
    return Visit(id: visitRef.id, member: member, start: slot.start, end: slot.end);
  }

  @override
  Future<void> cancel(Visit visit) => _cancel(visit, notify: true);

  Future<void> _cancel(Visit visit, {required bool notify}) async {
    final dayRef = _agenda.doc(dayKey(visit.start));
    await _db.runTransaction<void>((tx) async {
      final day = await tx.get(dayRef);
      final slots = _slotsOf(day.data()).where((s) => s['visitId'] != visit.id).toList();
      tx.update(_visitsRef.doc(visit.id), {'status': VisitStatus.cancelled.name});
      if (day.exists) tx.set(dayRef, {'slots': slots});
      if (notify) {
        tx.set(_notificationsRef.doc(), {
          'message': '${visit.member.name} cancelou a visita de ${dayKey(visit.start)}',
          'createdAt': fs.FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    });
  }

  // ---- Conversões ----

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Arredonda para ~1 km: suficiente para estimar o deslocamento sem expor o endereço.
  static fs.GeoPoint _approximate(GeoPoint p) =>
      fs.GeoPoint((p.lat * 100).roundToDouble() / 100, (p.lng * 100).roundToDouble() / 100);

  static List<Map<String, dynamic>> _slotsOf(Map<String, dynamic>? day) => [
    for (final s in (day?['slots'] as List<dynamic>? ?? const []))
      Map<String, dynamic>.from(s as Map),
  ];

  static DateTime _time(Object? v) => (v as fs.Timestamp).toDate();

  static GeoPoint _point(Object? v) {
    final p = v as fs.GeoPoint;
    return GeoPoint(p.latitude, p.longitude);
  }

  static AvailabilityWindow _windowFrom(fs.QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      AvailabilityWindow(id: doc.id, start: _time(doc['start']), end: _time(doc['end']));

  static Visit _visitFrom(fs.QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return Visit(
      id: doc.id,
      member: Member(
        id: d['memberId'] as String,
        name: d['memberName'] as String? ?? '',
        phone: d['memberPhone'] as String? ?? '',
        neighborhood: d['neighborhood'] as String? ?? '',
        location: _point(d['location']),
      ),
      start: _time(d['start']),
      end: _time(d['end']),
      status: VisitStatus.values.byName(d['status'] as String? ?? 'pending'),
    );
  }

  static Visit _busyVisitFrom(Map<String, dynamic> s) => Visit(
    id: s['visitId'] as String,
    member: Member(
      id: 'busy:${s['visitId']}',
      name: '',
      phone: '',
      neighborhood: s['neighborhood'] as String? ?? 'outro bairro',
      location: _point(s['area']),
    ),
    start: _time(s['start']),
    end: _time(s['end']),
  );

  static PastorNotification _notificationFrom(fs.QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final created = d['createdAt'];
    return PastorNotification(
      id: doc.id,
      message: d['message'] as String? ?? '',
      // Fica nulo por um instante, até o servidor preencher o horário.
      createdAt: created is fs.Timestamp ? created.toDate() : DateTime.now(),
      read: d['read'] as bool? ?? false,
    );
  }
}
