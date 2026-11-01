import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets.dart';
import '../data/modelos.dart';
import '../data/providers.dart';

class AjustesPage extends ConsumerWidget {
  const AjustesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    final u = ref.watch(usuarioProvider).value;
    final cfg = ref.watch(configProvider).value ?? const ConfigMidia();
    final o = (ref.watch(estadoProvider).value ?? const EstadoMidia()).obs;
    final lider = u?.comanda ?? false;
    final repo = ref.read(repoProvider);

    Future<void> salvar(ConfigMidia c) => guard(context, () => repo.salvarConfig(c));

    Future<void> editarCamera([int? i]) async {
      final atual = i == null ? null : cfg.cameras[i];
      final nome = await promptText(
        context,
        title: atual == null ? 'Nova câmera' : 'Nome da câmera',
        placeholder: 'Ex.: Câmera 1 · Púlpito',
        ok: 'Seguinte',
        required: true,
      );
      if (nome == null || nome.trim().isEmpty || !context.mounted) return;
      final fontes = {...o.fontesPrograma, ...o.fontesPrevia, ...o.cenas, ?atual?.fonte}.toList()..sort();
      String? fonte;
      if (fontes.isNotEmpty) {
        fonte = await showActionSheet<String>(
          context,
          title: 'Fonte ou cena do OBS desta câmera',
          message: 'A luz acende quando esta fonte estiver no programa.',
          actions: [
            for (final f in fontes) SheetAction(f, f, icon: CupertinoIcons.videocam),
            const SheetAction('Escrever o nome…', ''),
          ],
        );
        if (fonte == null || !context.mounted) return;
      }
      if (fonte == null || fonte.isEmpty) {
        fonte = await promptText(
          context,
          title: 'Nome da fonte no OBS',
          message: 'Exatamente como aparece no OBS.',
          required: true,
        );
      }
      if (fonte == null || fonte.trim().isEmpty) return;
      final lista = [...cfg.cameras];
      final c = Camera(nome.trim(), fonte.trim());
      if (i == null) {
        lista.add(c);
      } else {
        lista[i] = c;
      }
      await salvar(ConfigMidia(cameras: lista, rapidas: cfg.rapidas));
    }

    Future<void> novaRapida() async {
      final t = await promptText(context, title: 'Mensagem rápida', required: true);
      if (t == null || t.trim().isEmpty) return;
      await salvar(ConfigMidia(cameras: cfg.cameras, rapidas: [...cfg.rapidas, t.trim()]));
    }

    return AppScaffold(
      title: 'Ajustes',
      slivers: [
        SliverToBoxAdapter(
          child: Section(
            header: 'Conta',
            children: [
              ListRow(
                title: u?.nome.isNotEmpty == true ? u!.nome : '—',
                subtitle: [u?.role.label, u?.midia?.label].whereType<String>().join(' · '),
              ),
              ListRow(title: 'Sair', destructive: true, onTap: () => ref.read(authServiceProvider).signOut()),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Section(
            header: 'Câmeras',
            footer: lider
                ? 'Ligue cada câmera à fonte (ou cena) do OBS que a mostra. Segure para apagar.'
                : 'A liderança de mídia configura as câmeras.',
            children: [
              for (final (i, c) in cfg.cameras.indexed)
                ListRow(
                  leading: Icon(CupertinoIcons.videocam_fill, color: pal.accent),
                  title: c.nome,
                  subtitle: 'OBS: ${c.fonte}',
                  onTap: lider ? () => editarCamera(i) : null,
                  onLongPress: lider
                      ? () async {
                          if (await confirm(context, 'Apagar ${c.nome}?', ok: 'Apagar', destructive: true)) {
                            await salvar(ConfigMidia(cameras: [...cfg.cameras]..removeAt(i), rapidas: cfg.rapidas));
                          }
                        }
                      : null,
                ),
              if (lider) ListRow(title: 'Adicionar câmera', accent: true, onTap: editarCamera),
              if (cfg.cameras.isEmpty && !lider) const ListRow(title: 'Nenhuma câmera ainda'),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Section(
            header: 'Mensagens rápidas',
            footer: lider ? 'Segure uma mensagem para apagar.' : null,
            children: [
              for (final (i, r) in cfg.rapidas.indexed)
                ListRow(
                  title: r,
                  onLongPress: lider
                      ? () async {
                          if (await confirm(context, 'Apagar "$r"?', ok: 'Apagar', destructive: true)) {
                            await salvar(ConfigMidia(cameras: cfg.cameras, rapidas: [...cfg.rapidas]..removeAt(i)));
                          }
                        }
                      : null,
                ),
              if (lider) ListRow(title: 'Adicionar mensagem', accent: true, onTap: novaRapida),
            ],
          ),
        ),
        const SliverToBoxAdapter(
          child: Section(
            header: 'Como funciona',
            footer:
                'Um programa (a ponte) no computador da igreja lê o OBS e o servidor do telão '
                'e publica aqui o que está no ar. Os comandos feitos no app passam pela ponte. '
                'Quem entra na equipa de mídia é definido no app da igreja, em Usuários.',
          ),
        ),
      ],
    );
  }
}
