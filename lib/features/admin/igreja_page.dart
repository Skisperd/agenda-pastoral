import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/links.dart';
import '../../core/widgets.dart';
import '../../data/models/conteudo.dart';
import '../../data/providers.dart';
import '../common.dart';

/// Dados gerais: nome, contatos, redes, dados bancários e identificação das ofertas.
class IgrejaPage extends ConsumerStatefulWidget {
  const IgrejaPage({super.key});

  @override
  ConsumerState<IgrejaPage> createState() => _IgrejaPageState();
}

class _IgrejaPageState extends ConsumerState<IgrejaPage> {
  final _form = GlobalKey<FormState>();
  final _c = {
    for (final k in [..._igreja.keys, ..._contribua.keys, 'ofertas']) k: TextEditingController(),
  };
  bool _loaded = false;

  static const _igreja = {
    'name': ('Nome', 'Igreja…'),
    'shortName': ('Nome curto', 'Pedras Vivas'),
    'slogan': ('Lema', 'Conhecer a Cristo e fazê-lo conhecido'),
    'address': ('Morada', 'Rua, número, localidade'),
    'phone': ('Telefone', 'WhatsApp da secretaria'),
    'email': ('E-mail', 'secretaria@…'),
    'site': ('Site', 'https://…'),
    'instagram': ('Instagram', 'Link do perfil'),
    'youtube': ('YouTube', 'Link do canal'),
  };

  static const _contribua = {
    'banco': ('Banco', 'Banco BPI'),
    'iban': ('IBAN', 'PT50 …'),
    'swift': ('SWIFT', 'BBPIPTPL'),
    'pix': ('MB WAY', 'Opcional'),
  };

  static const _links = {'youtube', 'instagram', 'site'};

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    String? v(String k) => _c[k]!.text.trim().isEmpty ? null : _c[k]!.text.trim();
    final ofertas = [
      for (final l in _c['ofertas']!.text.split('\n'))
        if (l.contains('=')) {'tipo': l.split('=').first.trim(), 'valor': l.split('=').skip(1).join('=').trim()},
    ];
    final ok = await guard(
      context,
      () => ref
          .read(repoProvider)
          .saveIgreja(
            IgrejaConfig.fromMap({
              for (final k in [..._igreja.keys, ..._contribua.keys]) k: v(k),
              'ofertas': ofertas,
            }),
          ),
      success: 'Dados salvos',
    );
    if (ok && mounted) context.pop();
  }

  Widget _campo(String k, (String, String) c) => FieldRow(
    controller: _c[k]!,
    label: c.$1,
    placeholder: c.$2,
    labelWidth: 96,
    keyboardType: _links.contains(k) ? TextInputType.url : null,
    validator: _links.contains(k) ? (v) => isValidUrl(v) ? null : 'Link inválido' : null,
  );

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(roleProvider).isLeader) return const NoAccess(title: 'Dados da igreja');
    final igreja = ref.watch(igrejaProvider);
    if (!_loaded && igreja.hasValue) {
      final m = igreja.value!.toMap();
      for (final k in [..._igreja.keys, ..._contribua.keys]) {
        _c[k]!.text = m[k] as String? ?? '';
      }
      _c['ofertas']!.text = [for (final (t, v) in igreja.value!.ofertas) '$t = $v'].join('\n');
      _loaded = true;
    }
    return AppScaffold(
      title: 'Dados da igreja',
      large: false,
      previousPageTitle: 'Mais',
      maxWidth: kFormWidth,
      actions: [NavAction(label: 'Salvar', bold: true, onPressed: _save)],
      slivers: [
        SliverToBoxAdapter(
          child: Form(
            key: _form,
            child: Column(
              children: [
                Section(
                  header: 'Igreja',
                  footer: 'Aparecem no boletim, em Contatos e nos textos enviados pelo WhatsApp.',
                  children: [for (final e in _igreja.entries) _campo(e.key, e.value)],
                ),
                Section(header: 'Contribua', children: [for (final e in _contribua.entries) _campo(e.key, e.value)]),
                Section(
                  header: 'Identificação das ofertas',
                  footer: 'Uma por linha, no formato "Dízimo = + 0,01 €".',
                  children: [
                    FieldRow(controller: _c['ofertas']!, placeholder: 'Dízimo = + 0,01 €', maxLines: 8, minLines: 3),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
