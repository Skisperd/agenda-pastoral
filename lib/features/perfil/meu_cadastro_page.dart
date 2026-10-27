import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/pickers.dart';
import '../../core/widgets.dart';
import '../../data/models/people.dart';
import '../../data/providers.dart';

/// A própria pessoa mantém contato e endereço em dia (o endereço é usado na
/// agenda pastoral). Quem ainda não tem cadastro cria o seu aqui.
class MeuCadastroPage extends ConsumerStatefulWidget {
  const MeuCadastroPage({super.key});

  @override
  ConsumerState<MeuCadastroPage> createState() => _MeuCadastroPageState();
}

class _MeuCadastroPageState extends ConsumerState<MeuCadastroPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _bairro = TextEditingController();
  String? _birth, _marital, _wedding;
  Membro? _original;
  bool _loaded = false, _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _address, _bairro]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(AppUser u, Membro? m) {
    _original = m;
    _name.text = m?.name ?? u.name;
    _phone.text = m?.phone ?? '';
    _email.text = m?.email ?? u.email;
    _address.text = m?.address ?? '';
    _bairro.text = m?.neighborhood ?? '';
    _birth = m?.birthDate;
    _marital = m?.maritalStatus;
    _wedding = m?.weddingDate;
  }

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final user = ref.read(currentUserProvider).value!;
    final repo = ref.read(repoProvider);
    final address = _t(_address);
    double? lat = _original?.lat, lng = _original?.lng;
    String? aviso;
    if (address != null && (address != _original?.address || lat == null)) {
      try {
        final p = await ref.read(geocoderProvider).find(address);
        lat = p?.lat;
        lng = p?.lng;
        if (p == null) aviso = 'Não achamos o endereço no mapa. Confira rua, número e cidade.';
      } catch (_) {
        aviso = 'Não foi possível localizar o endereço agora. Tente salvar de novo.';
      }
    }
    if (address == null) lat = lng = null;
    final fields = <String, dynamic>{
      'name': _name.text.trim(),
      'phone': _t(_phone),
      'email': _t(_email),
      'address': address,
      'neighborhood': _t(_bairro),
      'lat': lat,
      'lng': lng,
      'birthDate': _birth,
      'maritalStatus': _marital,
      'weddingDate': _wedding,
    };
    if (!mounted) return;
    final ok = await guard(context, () async {
      if (user.memberId == null) {
        await repo.createOwnMember(user.uid, Membro.fromMap(user.uid, fields));
      } else {
        await repo.saveOwnMember(user.memberId!, fields);
      }
      if (_name.text.trim() != user.name) await repo.renameSelf(user.uid, _name.text);
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      toast(context, aviso ?? 'Cadastro atualizado');
      if (aviso == null) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final member = ref.watch(myMemberProvider);
    if (user == null) return const AppScaffold(title: 'Meu cadastro', large: false);
    if (!_loaded && (user.memberId == null || member.hasValue)) {
      _load(user, member.value);
      _loaded = true;
    }
    final m = member.value;
    return AppScaffold(
      title: 'Meu cadastro',
      large: false,
      previousPageTitle: 'Mais',
      maxWidth: kFormWidth,
      actions: [NavAction(label: _saving ? 'Salvando…' : 'Salvar', bold: true, onPressed: _saving ? null : _save)],
      slivers: [
        if (m != null)
          SliverToBoxAdapter(
            child: Section(
              children: [
                ListRow(title: 'Situação', value: m.situacao.label),
                if (m.oficio != null) ListRow(title: 'Ofício', value: m.oficio!.label),
              ],
            ),
          ),
        if (user.memberId == null)
          SliverToBoxAdapter(
            child: NoticeCard(
              icon: Icons.person_add_alt_1,
              title: 'Complete seu cadastro',
              message: 'A secretaria confere depois. Com o endereço, você já pode pedir uma visita pastoral.',
              color: context.pal.accent,
            ),
          ),
        SliverToBoxAdapter(
          child: Form(
            key: _form,
            child: Column(
              children: [
                Section(
                  header: 'Dados',
                  children: [
                    FieldRow(
                      controller: _name,
                      label: 'Nome',
                      capitalization: TextCapitalization.words,
                      validator: (v) => (v ?? '').trim().length < 3 ? 'Informe seu nome' : null,
                    ),
                    DateRow(label: 'Nascimento', value: _birth, onChanged: (v) => setState(() => _birth = v)),
                    ChoiceRow<String>(
                      label: 'Estado civil',
                      value: _marital,
                      options: {for (final e in estadosCivis) e: e},
                      onChanged: (v) => setState(() => _marital = v),
                    ),
                    if (_marital == 'Casado(a)')
                      DateRow(label: 'Casamento', value: _wedding, onChanged: (v) => setState(() => _wedding = v)),
                  ],
                ),
                Section(
                  header: 'Contato e endereço',
                  footer:
                      'O endereço só é visto pelo pastor e pela secretaria. Para os outros membros, a agenda '
                      'pastoral mostra apenas o bairro, para calcular o trajeto.',
                  children: [
                    FieldRow(
                      controller: _phone,
                      label: 'Celular',
                      placeholder: '(11) 98765-4321',
                      keyboardType: TextInputType.phone,
                    ),
                    FieldRow(controller: _email, label: 'E-mail', keyboardType: TextInputType.emailAddress),
                    FieldRow(
                      controller: _address,
                      label: 'Endereço',
                      placeholder: 'Rua, número, bairro, cidade',
                      maxLines: 2,
                      capitalization: TextCapitalization.words,
                    ),
                    FieldRow(
                      controller: _bairro,
                      label: 'Região',
                      placeholder: 'Ex.: Santana · Zona Norte',
                      capitalization: TextCapitalization.words,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: PrimaryButton(label: 'Salvar', loading: _saving, onPressed: _save),
          ),
        ),
      ],
    );
  }
}
