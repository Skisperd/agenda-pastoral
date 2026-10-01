import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../ui/member_page.dart';
import '../ui/pastor_page.dart';
import 'firestore_agenda_store.dart';
import 'login_page.dart';
import 'profile_page.dart';

/// Decide a tela inicial: login → cadastro → área do pastor ou do membro.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, auth) {
        if (auth.connectionState == ConnectionState.waiting) return const _Loading();
        final user = auth.data;
        if (user == null) return const LoginPage();
        return _ProfileGate(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

class _ProfileGate extends StatefulWidget {
  const _ProfileGate({super.key, required this.user});

  final User user;

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  FirestoreAgendaStore? _store;
  String? _storeKey;

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  /// Recria o store só quando muda o perfil relevante (papel ou dados do membro).
  FirestoreAgendaStore _storeFor(UserProfile profile, Map<String, dynamic> data) {
    final key = '${data['role']}|${data['name']}|${data['neighborhood']}|${data['location']}';
    if (_store == null || key != _storeKey) {
      _store?.dispose();
      _store = FirestoreAgendaStore(firestore: fs.FirebaseFirestore.instance, profile: profile);
      _storeKey = key;
    }
    return _store!;
  }

  @override
  Widget build(BuildContext context) {
    final doc = fs.FirebaseFirestore.instance.collection('users').doc(widget.user.uid);
    return StreamBuilder<fs.DocumentSnapshot<Map<String, dynamic>>>(
      stream: doc.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _Message(text: 'Não foi possível carregar seu cadastro.\n${snap.error}');
        }
        if (!snap.hasData) return const _Loading();
        final data = snap.data!.data();
        if (data == null) return ProfilePage(user: widget.user);

        final location = data['location'] as fs.GeoPoint;
        final profile = UserProfile(
          isPastor: data['role'] == 'pastor',
          member: Member(
            id: widget.user.uid,
            name: data['name'] as String? ?? '',
            phone: data['phone'] as String? ?? '',
            neighborhood: data['neighborhood'] as String? ?? '',
            location: GeoPoint(location.latitude, location.longitude),
          ),
        );
        final store = _storeFor(profile, data);
        final signOut = IconButton(
          tooltip: 'Sair',
          icon: const Icon(Icons.logout),
          onPressed: () => FirebaseAuth.instance.signOut(),
        );
        return profile.isPastor
            ? PastorPage(store: store, extraActions: [signOut])
            : MemberPage(
                store: store,
                member: profile.member,
                extraActions: [
                  IconButton(
                    tooltip: 'Meu cadastro',
                    icon: const Icon(Icons.manage_accounts_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfilePage(user: widget.user, current: data),
                      ),
                    ),
                  ),
                  signOut,
                ],
              );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(padding: const EdgeInsets.all(24), child: Text(text)),
    ),
  );
}
