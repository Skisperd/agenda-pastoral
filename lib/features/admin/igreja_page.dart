import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/links.dart';
import '../../core/widgets.dart';
import '../../data/models/conteudo.dart';
import '../../data/providers.dart';
import '../common.dart';

/// Dados gerais: nome, endereço, contatos da secretaria, canal do YouTube e PIX.
class IgrejaPage extends ConsumerStatefulWidget {
  const IgrejaPage({super.key});

  @override
  ConsumerState<IgrejaPage> createState() => _IgrejaPageState();
}

class _IgrejaPageState extends ConsumerState<IgrejaPage> {
  final _form = GlobalKey<FormState>();
  final _c = {for (final k in _campos.keys) k: TextEditingController()};
  bool _loaded = false;

  static const _campos = {
    'name': ('Nome', 'Igreja…'),
    'shortName': ('Nome curto', 'Pedras Vivas'),
    'address': ('Endereço', 'Rua, número, cidade'),
    'phone': ('Telefone', 'WhatsApp da secretaria'),
    'email': ('E-mail', 'secretaria@…'),
    'youtube': ('YouTube', 'Link do canal'),
    'instagram': ('Instagram', 'Link do perfil'),
    'site': ('Site', 'https://…'),
    'pix': ('PIX', 'Chave para dízimos e ofertas'),
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
    final ok = await guard(
      context,
      () => ref.read(repoProvider).saveIgreja(IgrejaConfig.fromMap({for (final k in _campos.keys) k: v(k)})),
      success: 'Dados salvos',
    );
    if (ok && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(roleProvider).isLeader) return const NoAccess(title: 'Dados da igreja');
    final igreja = ref.watch(igrejaProvider);
    if (!_loaded && igreja.hasValue) {
      final m = igreja.value!.toMap();
      for (final e in _c.entries) {
        e.value.text = m[e.key] as String? ?? '';
      }
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
            child: Section(
              footer: 'Aparecem em Contatos, no menu Mais e nos textos compartilhados no WhatsApp.',
              children: [
                for (final e in _campos.entries)
                  FieldRow(
                    controller: _c[e.key]!,
                    label: e.value.$1,
                    placeholder: e.value.$2,
                    labelWidth: 96,
                    keyboardType: _links.contains(e.key) ? TextInputType.url : null,
                    validator: _links.contains(e.key) ? (v) => isValidUrl(v) ? null : 'Link inválido' : null,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
