import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'geocoder.dart';

/// Cadastro do membro. O endereço vira coordenadas para o cálculo de deslocamento.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user, this.current, this.geocoder});

  final User user;

  /// Dados atuais, quando é uma edição.
  final Map<String, dynamic>? current;
  final Geocoder? geocoder;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.current?['name'] as String?);
  late final _phone = TextEditingController(text: widget.current?['phone'] as String?);
  late final _address = TextEditingController(text: widget.current?['address'] as String?);
  late final _neighborhood = TextEditingController(
    text: widget.current?['neighborhood'] as String?,
  );
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _neighborhood]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final point = await (widget.geocoder ?? NominatimGeocoder()).find(_address.text.trim());
      if (point == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Endereço não encontrado no mapa. Confira rua, número e cidade.'),
          ),
        );
        return;
      }
      final doc = fs.FirebaseFirestore.instance.collection('users').doc(widget.user.uid);
      final data = <String, dynamic>{
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'neighborhood': _neighborhood.text.trim(),
        'location': fs.GeoPoint(point.lat, point.lng),
        'email': widget.user.email,
      };
      if (widget.current == null) {
        await doc.set({...data, 'role': 'member'});
      } else {
        await doc.update(data);
        navigator.pop();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.current != null;
    InputDecoration field(String label, [String? hint]) =>
        InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder());
    String? required(String? v) => (v ?? '').trim().isEmpty ? 'Campo obrigatório' : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Meu cadastro' : 'Complete seu cadastro'),
        actions: [
          if (!editing)
            IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout),
              onPressed: () => FirebaseAuth.instance.signOut(),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!editing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Seu endereço é usado só para calcular o tempo de deslocamento do pastor. '
                      'Outros membros não veem seus dados.',
                    ),
                  ),
                TextFormField(
                  controller: _name,
                  decoration: field('Nome', 'Como a igreja te conhece'),
                  validator: required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: field('Telefone / WhatsApp'),
                  validator: required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  decoration: field('Endereço completo', 'Rua, número, cidade'),
                  validator: required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _neighborhood,
                  decoration: field('Bairro'),
                  validator: required,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Salvando…' : 'Salvar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
