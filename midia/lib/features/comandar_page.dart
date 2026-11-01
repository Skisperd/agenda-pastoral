import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/widgets.dart';
import '../data/modelos.dart';
import '../data/providers.dart';
import 'comum.dart';

/// Comandos para o OBS e o telão, executados pela ponte no computador da igreja.
class ComandarPage extends ConsumerWidget {
  const ComandarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    final u = ref.watch(usuarioProvider).value;
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final e = ref.watch(estadoProvider).value ?? const EstadoMidia();
    final cmds = ref.watch(meusComandosProvider).value ?? const <Comando>[];
    final o = e.obs, t = e.telao;
    final online = e.ponteOnline(agora);

    if (u == null || !u.comanda) {
      return const AppScaffold(
        title: 'Comandar',
        slivers: [
          SliverToBoxAdapter(
            child: EmptyState(
              icon: CupertinoIcons.lock,
              title: 'Só a liderança de mídia comanda',
              message: 'Você acompanha tudo em Ao vivo e na Câmera. Use as Mensagens para pedir uma troca.',
            ),
          ),
        ],
      );
    }

    Future<void> enviar(String tipo, [String? valor]) async {
      unawaited(HapticFeedback.mediumImpact());
      await guard(context, () => ref.read(repoProvider).enviarComando(u, tipo, valor));
    }

    Future<void> confirmar(String titulo, String tipo) async {
      if (await confirm(context, titulo, ok: 'Sim', destructive: tipo.endsWith('parar'))) await enviar(tipo);
    }

    Widget botaoCena(String c) {
      final noAr = c == o.programa, naPrevia = o.modoEstudio && c == o.previa;
      final cor = noAr ? Tally.programa.cor(pal) : (naPrevia ? Tally.previa.cor(pal) : pal.card);
      return GestureDetector(
        onTap: () => enviar(o.modoEstudio ? 'obs.previa' : 'obs.programa', c),
        onLongPress: o.modoEstudio ? () => enviar('obs.programa', c) : null,
        child: Container(
          width: 150,
          height: 64,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(12)),
          child: Text(
            c,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w700, color: noAr || naPrevia ? Colors.white : pal.label),
          ),
        ),
      );
    }

    return AppScaffold(
      title: 'Comandar',
      slivers: [
        if (!online)
          SliverToBoxAdapter(
            child: NoticeCard(
              icon: CupertinoIcons.desktopcomputer,
              title: 'Ponte desligada',
              message: 'Os comandos ficam à espera até a ponte voltar.',
              color: pal.orange,
            ),
          ),
        SliverToBoxAdapter(
          child: Section(
            header: o.modoEstudio ? 'Cenas do OBS · toque = prévia, segure = no ar' : 'Cenas do OBS · toque = no ar',
            plain: true,
            children: [
              if (o.cenas.isEmpty)
                Text('Sem cenas (OBS desconectado?)', style: TextStyle(color: pal.secondaryLabel))
              else
                Wrap(spacing: 10, runSpacing: 10, children: [for (final c in o.cenas) botaoCena(c)]),
              if (o.modoEstudio) ...[
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'TRANSIÇÃO',
                  icon: CupertinoIcons.arrow_right_arrow_left,
                  color: Tally.programa.cor(pal),
                  onPressed: () => enviar('obs.transicao'),
                ),
              ],
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Section(
            header: 'Transmissão e gravação',
            children: [
              ListRow(
                leading: Icon(CupertinoIcons.dot_radiowaves_left_right, color: o.transmitindo ? pal.red : pal.gray),
                title: o.transmitindo ? 'Ao vivo · ${duracao(o.transmissaoMs)}' : 'Transmissão parada',
                trailing: TintButton(
                  label: o.transmitindo ? 'Parar' : 'Iniciar',
                  color: o.transmitindo ? pal.red : pal.green,
                  onPressed: () => o.transmitindo
                      ? confirmar('Parar a transmissão?', 'obs.transmissao.parar')
                      : confirmar('Iniciar a transmissão?', 'obs.transmissao.iniciar'),
                ),
              ),
              ListRow(
                leading: Icon(CupertinoIcons.recordingtape, color: o.gravando ? pal.orange : pal.gray),
                title: o.gravando ? 'Gravando · ${duracao(o.gravacaoMs)}' : 'Gravação parada',
                trailing: TintButton(
                  label: o.gravando ? 'Parar' : 'Gravar',
                  color: o.gravando ? pal.red : pal.green,
                  onPressed: () => o.gravando
                      ? confirmar('Parar a gravação?', 'obs.gravacao.parar')
                      : confirmar('Iniciar a gravação?', 'obs.gravacao.iniciar'),
                ),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Section(
            header: 'Telão',
            plain: true,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TintButton(
                      label: 'Anterior',
                      icon: CupertinoIcons.backward_fill,
                      large: true,
                      expand: true,
                      onPressed: () => enviar('holyrics.anterior'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TintButton(
                      label: 'Próximo',
                      icon: CupertinoIcons.forward_fill,
                      large: true,
                      expand: true,
                      onPressed: () => enviar('holyrics.proximo'),
                    ),
                  ),
                ],
              ),
              if (t.cenas.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in t.cenas)
                      TintButton(
                        label: c.nome,
                        color: c.id == t.cena ? pal.green : null,
                        onPressed: () => enviar('telao.cena', c.id),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (cmds.isNotEmpty)
          SliverToBoxAdapter(
            child: Section(
              header: 'Meus últimos comandos',
              children: [
                for (final c in cmds.take(8))
                  ListRow(
                    leading: Icon(
                      switch (c.status) {
                        StatusComando.pendente => CupertinoIcons.clock,
                        StatusComando.feito => CupertinoIcons.checkmark_circle_fill,
                        StatusComando.erro => CupertinoIcons.xmark_circle_fill,
                      },
                      color: switch (c.status) {
                        StatusComando.pendente => pal.orange,
                        StatusComando.feito => pal.green,
                        StatusComando.erro => pal.red,
                      },
                    ),
                    title: c.descricao,
                    subtitle: [
                      if (c.createdAt.isNotEmpty) hhmm(DateTime.parse(c.createdAt).toLocal()),
                      ?c.resultado,
                    ].join(' · '),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
