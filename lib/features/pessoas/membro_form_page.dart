import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/pickers.dart';
import '../../core/roles.dart';
import '../../core/widgets.dart';
import '../../data/models/people.dart';
import '../../data/providers.dart';
import '../common.dart';

/// Cadastro completo de membro (secretaria, pastor e conselho).
class MembroFormPage extends ConsumerStatefulWidget {
  const MembroFormPage({super.key, this.id});
  final String? id;

  @override
  ConsumerState<MembroFormPage> createState() => _MembroFormPageState();
}

class _MembroFormPageState extends ConsumerState<MembroFormPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _bairro = TextEditingController();
  final _family = TextEditingController();
  Situacao _situacao = Situacao.comungante;
  Oficio? _oficio;
  String? _birth, _wedding, _baptism, _profession, _admission, _marital, _admissionMode;
  List<String> _ministries = [];
  List<FuncaoDiaconal> _funcoes = [];
  Membro? _original;
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _address, _bairro, _family]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(Membro m) {
    _original = m;
    _name.text = m.name;
    _phone.text = m.phone ?? '';
    _email.text = m.email ?? '';
    _address.text = m.address ?? '';
    _bairro.text = m.neighborhood ?? '';
    _family.text = m.family ?? '';
    _situacao = m.selfRegistered && m.situacao == Situacao.visitante ? Situacao.visitante : m.situacao;
    _oficio = m.oficio;
    _birth = m.birthDate;
    _wedding = m.weddingDate;
    _baptism = m.baptismDate;
    _profession = m.professionDate;
    _admission = m.admissionDate;
    _marital = m.maritalStatus;
    _admissionMode = m.admissionMode;
    _ministries = [...m.ministries];
    _funcoes = [...m.funcoes];
  }

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final me = ref.read(currentUserProvider).value!;
    final address = _t(_address);
    double? lat = _original?.lat, lng = _original?.lng;
    String? aviso;
    if (address != null && (address != _original?.address || lat == null)) {
      try {
        final p = await ref.read(geocoderProvider).find(address);
        lat = p?.lat;
        lng = p?.lng;
        if (p == null) aviso = 'Endereço não encontrado no mapa: a agenda pastoral não vai calcular o deslocamento.';
      } catch (_) {
        aviso = 'Não foi possível localizar o endereço agora. Salve de novo mais tarde.';
      }
    }
    if (address == null) lat = lng = null;
    final m = Membro(
      id: widget.id ?? '',
      name: _name.text,
      situacao: _situacao,
      oficio: _oficio,
      birthDate: _birth,
      phone: _t(_phone),
      email: _t(_email),
      address: address,
      neighborhood: _t(_bairro),
      lat: lat,
      lng: lng,
      maritalStatus: _marital,
      weddingDate: _wedding,
      family: _t(_family),
      baptismDate: _baptism,
      professionDate: _profession,
      admissionDate: _admission,
      admissionMode: _admissionMode,
      ministries: _ministries,
      funcoes: _funcoes,
    );
    if (!mounted) return;
    String? id;
    final ok = await guard(context, () async => id = await ref.read(repoProvider).saveMember(m, byUid: me.uid));
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    toast(context, aviso ?? 'Cadastro salvo');
    context.go('/pessoas/$id');
  }

  Future<void> _pickMinistries() async {
    final sel = {..._ministries};
    final extra = [
      for (final m in _ministries)
        if (!ministeriosSugeridos.contains(m)) m,
    ];
    await showSheet<void>(
      context,
      tall: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => Column(
          children: [
            SheetHeader(title: 'Ministérios', action: 'OK', onAction: () => Navigator.pop(c), cancel: null),
            Expanded(
              child: ListView(
                children: [
                  Section(
                    children: [
                      for (final m in [...ministeriosSugeridos, ...extra])
                        ListRow(
                          title: m,
                          trailing: sel.contains(m)
                              ? Icon(CupertinoIcons.checkmark_alt, color: c.pal.accent)
                              : const SizedBox(width: 22),
                          onTap: () => setS(() => sel.contains(m) ? sel.remove(m) : sel.add(m)),
                        ),
                      ListRow(
                        title: 'Outro…',
                        accent: true,
                        onTap: () async {
                          final v = await promptText(c, title: 'Ministério', placeholder: 'Nome');
                          if (v == null || v.isEmpty) return;
                          setS(() {
                            extra.add(v);
                            sel.add(v);
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    setState(() => _ministries = [...sel]);
  }

  Future<void> _pickFuncoes() async {
    final sel = {..._funcoes};
    await showSheet<void>(
      context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(title: 'Funções na escala', action: 'OK', onAction: () => Navigator.pop(c), cancel: null),
              Section(
                footer: 'Nenhuma marcada = pode ser escalado em qualquer função.',
                children: [
                  for (final f in FuncaoDiaconal.values)
                    ListRow(
                      leading: IconTile(f.icon, color: f.color(c.pal)),
                      title: f.label,
                      trailing: sel.contains(f)
                          ? Icon(CupertinoIcons.checkmark_alt, color: c.pal.accent)
                          : const SizedBox(width: 22),
                      onTap: () => setS(() => sel.contains(f) ? sel.remove(f) : sel.add(f)),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
    setState(
      () => _funcoes = [
        for (final f in FuncaoDiaconal.values)
          if (sel.contains(f)) f,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(roleProvider);
    if (!role.canManageMembers) return const NoAccess(title: 'Cadastro');
    if (widget.id != null && !_loaded) {
      final m = ref.watch(memberProvider(widget.id!)).value;
      if (m == null) return const AppScaffold(title: 'Editar', large: false);
      _load(m);
      _loaded = true;
    }
    final servesDiaconia = _oficio == Oficio.diacono || _ministries.any((m) => m.toLowerCase().startsWith('diacon'));
    return AppScaffold(
      title: widget.id == null ? 'Novo cadastro' : 'Editar cadastro',
      large: false,
      maxWidth: kFormWidth,
      leading: NavAction(label: 'Cancelar', onPressed: () => context.pop()),
      actions: [NavAction(label: _saving ? 'Salvando…' : 'Salvar', bold: true, onPressed: _saving ? null : _save)],
      slivers: [
        SliverToBoxAdapter(
          child: Form(
            key: _form,
            child: Column(
              children: [
                Section(
                  header: 'Pessoa',
                  children: [
                    FieldRow(
                      controller: _name,
                      label: 'Nome',
                      placeholder: 'Nome completo',
                      capitalization: TextCapitalization.words,
                      validator: (v) => (v ?? '').trim().length < 3 ? 'Informe o nome' : null,
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
                    FieldRow(
                      controller: _family,
                      label: 'Família',
                      placeholder: 'Ex.: Família Oliveira',
                      capitalization: TextCapitalization.words,
                    ),
                  ],
                ),
                Section(
                  header: 'Contato',
                  children: [
                    FieldRow(
                      controller: _phone,
                      label: 'Celular',
                      placeholder: '(11) 98765-4321',
                      keyboardType: TextInputType.phone,
                    ),
                    FieldRow(
                      controller: _email,
                      label: 'E-mail',
                      placeholder: 'nome@email.com',
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => (v ?? '').trim().isEmpty || v!.contains('@') ? null : 'E-mail inválido',
                    ),
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
                Section(
                  header: 'Igreja',
                  children: [
                    ChoiceRow<Situacao>(
                      label: 'Situação',
                      value: _situacao,
                      options: {for (final s in Situacao.values) s: s.label},
                      onChanged: (v) => setState(() => _situacao = v ?? _situacao),
                    ),
                    ChoiceRow<String>(
                      label: 'Ofício',
                      value: _oficio?.name ?? '-',
                      options: {'-': 'Nenhum', for (final o in Oficio.values) o.name: o.label},
                      onChanged: (v) => setState(() => _oficio = Oficio.tryParse(v)),
                    ),
                    ChoiceRow<String>(
                      label: 'Admissão',
                      value: _admissionMode,
                      options: {for (final e in modosAdmissao) e: e},
                      onChanged: (v) => setState(() => _admissionMode = v),
                    ),
                    DateRow(
                      label: 'Data da admissão',
                      value: _admission,
                      onChanged: (v) => setState(() => _admission = v),
                    ),
                    DateRow(label: 'Batismo', value: _baptism, onChanged: (v) => setState(() => _baptism = v)),
                    DateRow(
                      label: 'Profissão de fé',
                      value: _profession,
                      onChanged: (v) => setState(() => _profession = v),
                    ),
                    ListRow(
                      title: 'Ministérios',
                      value: _ministries.isEmpty ? 'Nenhum' : '${_ministries.length}',
                      subtitle: _ministries.isEmpty ? null : _ministries.join(', '),
                      onTap: _pickMinistries,
                    ),
                    if (servesDiaconia)
                      ListRow(
                        title: 'Funções na escala diaconal',
                        subtitle: _funcoes.isEmpty ? 'Todas' : _funcoes.map((f) => f.label).join(', '),
                        onTap: _pickFuncoes,
                      ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(32, 10, 32, 0),
                  child: Text(
                    'Com o endereço, o app calcula o deslocamento do pastor nas visitas. '
                    'Os dados ficam visíveis só para a secretaria, o pastor e o conselho.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
