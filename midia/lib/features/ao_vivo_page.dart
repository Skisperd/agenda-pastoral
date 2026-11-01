import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/modelos.dart';
import '../data/providers.dart';
import 'comum.dart';

/// Tudo o que está no ar: OBS (programa, prévia, transmissão), câmeras, telão.
class AoVivoPage extends ConsumerWidget {
  const AoVivoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    final agora = ref.watch(agoraProvider).value ?? DateTime.now();
    final e = ref.watch(estadoProvider).value ?? const EstadoMidia();
    final (img, em) = ref.watch(previaProvider).value ?? (null, null);
    final cfg = ref.watch(configProvider).value ?? const ConfigMidia();
    final msgs = ref.watch(mensagensProvider).value ?? const <Mensagem>[];
    final online = e.ponteOnline(agora);
    final o = e.obs, t = e.telao;
    return AppScaffold(
      title: 'Ao vivo',
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Sinal(online ? 'Ponte ligada' : 'Ponte desligada', cor: online ? pal.green : pal.red),
                if (online) Sinal(o.conectado ? 'OBS' : 'OBS desconectado', cor: o.conectado ? pal.green : pal.red),
                if (online && o.transmitindo)
                  Sinal('AO VIVO ${duracao(o.transmissaoMs)}', cor: const Color(0xFFE5292E))
                else if (online && o.conectado)
                  Sinal('Sem transmissão', cor: pal.gray),
                if (online && o.gravando) Sinal('GRAVANDO ${duracao(o.gravacaoMs)}', cor: pal.orange),
                if (online) Sinal(t.conectado ? 'Telão' : 'Telão desconectado', cor: t.conectado ? pal.green : pal.red),
              ],
            ),
          ),
        ),
        if (!online)
          SliverToBoxAdapter(
            child: NoticeCard(
              icon: CupertinoIcons.desktopcomputer,
              title: 'A ponte não está a responder',
              message: e.ponteEm == null
                  ? 'Instale a ponte no computador da igreja (pasta ponte_midia).'
                  : 'Último sinal: ${fmtDateTime(e.ponteEm!)}. Confira se o computador da igreja está ligado.',
              color: pal.orange,
            ),
          ),
        if (online && !o.conectado && o.erro != null)
          SliverToBoxAdapter(
            child: NoticeCard(
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              title: 'OBS',
              message: o.erro,
              color: pal.red,
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: MiniaturaObs(imagem: online ? img : null, cena: o.programa, em: em),
          ),
        ),
        SliverToBoxAdapter(
          child: Section(
            header: 'OBS',
            children: [
              ListRow(
                leading: Sinal('NO AR', cor: Tally.programa.cor(pal)),
                title: o.programa ?? '—',
              ),
              if (o.modoEstudio)
                ListRow(
                  leading: Sinal('PRÉVIA', cor: Tally.previa.cor(pal)),
                  title: o.previa ?? '—',
                ),
            ],
          ),
        ),
        if (cfg.cameras.isNotEmpty)
          SliverToBoxAdapter(
            child: Section(
              header: 'Câmeras',
              plain: true,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in cfg.cameras)
                      Container(
                        width: 108,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        decoration: BoxDecoration(color: c.tally(o).cor(pal), borderRadius: BorderRadius.circular(14)),
                        child: Column(
                          children: [
                            const Icon(CupertinoIcons.videocam_fill, color: Colors.white),
                            const SizedBox(height: 4),
                            Text(
                              c.nome,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              c.tally(o).label,
                              style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        SliverToBoxAdapter(
          child: Section(
            header: 'Telão',
            children: [
              ListRow(title: 'Cena', value: t.nomeCena ?? '—'),
              ListRow(title: t.rotulo, subtitle: [t.descricao, ?t.leitor].where((s) => s.isNotEmpty).join(' · ')),
              if (t.texto.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    t.texto,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: brandFont, fontSize: 22, height: 1.25),
                  ),
                ),
              if (t.conectado && !t.holyrics) const ListRow(title: 'Holyrics não responde ao servidor do telão'),
            ],
          ),
        ),
        if (msgs.isNotEmpty)
          SliverToBoxAdapter(
            child: Section(
              header: 'Mensagens',
              trailing: NavAction(label: 'Ver todas', onPressed: () => context.go('/mensagens')),
              children: [
                for (final m in msgs.reversed.take(3))
                  ListRow(title: m.texto, subtitle: '${m.nome} · ${m.para.label} · ${fmtDateTime(m.createdAt)}'),
              ],
            ),
          ),
      ],
    );
  }
}
