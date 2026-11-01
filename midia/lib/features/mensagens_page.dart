import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/widgets.dart';
import '../data/modelos.dart';
import '../data/providers.dart';

/// Conversa da equipa durante o culto, com mensagens rápidas de um toque.
class MensagensPage extends ConsumerStatefulWidget {
  const MensagensPage({super.key});

  @override
  ConsumerState<MensagensPage> createState() => _MensagensPageState();
}

class _MensagensPageState extends ConsumerState<MensagensPage> {
  final _texto = TextEditingController();
  Destino _para = Destino.todos;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _enviar(String texto) async {
    final u = ref.read(usuarioProvider).value;
    if (u == null || texto.trim().isEmpty) return;
    _texto.clear();
    unawaited(HapticFeedback.lightImpact());
    await guard(context, () => ref.read(repoProvider).enviarMensagem(u, texto, _para));
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final me = ref.watch(usuarioProvider).value;
    final msgs = ref.watch(mensagensProvider).value ?? const <Mensagem>[];
    final rapidas = (ref.watch(configProvider).value ?? const ConfigMidia()).rapidas;
    return Scaffold(
      backgroundColor: pal.background,
      appBar: CupertinoNavigationBar(middle: const Text('Mensagens'), backgroundColor: pal.bar),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: msgs.isEmpty
                  ? const EmptyState(icon: CupertinoIcons.chat_bubble_2, title: 'Nenhuma mensagem ainda')
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) {
                        final m = msgs[msgs.length - 1 - i];
                        final minha = m.uid == me?.uid;
                        return Align(
                          alignment: minha ? Alignment.centerRight : Alignment.centerLeft,
                          child: GestureDetector(
                            onLongPress: (me?.comanda ?? false) || minha
                                ? () async {
                                    if (await confirm(context, 'Apagar mensagem?', ok: 'Apagar', destructive: true)) {
                                      await ref.read(repoProvider).apagarMensagem(m.id);
                                    }
                                  }
                                : null,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 320),
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: minha ? pal.accent.withValues(alpha: .25) : pal.card,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${minha ? 'Você' : m.nome}${m.para == Destino.todos ? '' : ' → ${m.para.label}'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: pal.secondaryLabel,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(m.texto, style: context.text.bodyLarge),
                                  Text(
                                    m.createdAt.isEmpty ? '' : hhmm(DateTime.parse(m.createdAt).toLocal()),
                                    style: TextStyle(fontSize: 11, color: pal.tertiaryLabel),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            ChipBar<Destino>(
              items: {for (final d in Destino.values) d: d.label},
              selected: _para,
              onSelected: (d) => setState(() => _para = d),
            ),
            const SizedBox(height: 8),
            // Botões grandes de um toque: no culto não dá tempo de escrever.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 132),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final r in rapidas) TintButton(label: r, onPressed: () => _enviar(r))],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _texto,
                      placeholder: 'Mensagem para ${_para.label.toLowerCase()}',
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      style: context.text.bodyLarge,
                      decoration: BoxDecoration(color: pal.card, borderRadius: BorderRadius.circular(20)),
                      onSubmitted: _enviar,
                    ),
                  ),
                  const SizedBox(width: 8),
                  NavAction(icon: CupertinoIcons.arrow_up_circle_fill, onPressed: () => _enviar(_texto.text)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
