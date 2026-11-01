import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/modelos.dart';
import '../data/providers.dart';
import 'comum.dart';

/// Luz "no ar" do operador: o ecrã inteiro fica vermelho quando a câmera dele
/// está no programa e verde quando está na prévia.
class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> {
  String? _camera;
  Tally? _anterior;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) => mounted ? setState(() => _camera = p.getString('camera')) : null)
        .catchError((_) {});
    WakelockPlus.enable().catchError((_) {});
  }

  @override
  void dispose() {
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  Future<void> _escolher(ConfigMidia cfg) async {
    final c = await showActionSheet<String>(
      context,
      title: 'Qual câmera você opera?',
      actions: [for (final c in cfg.cameras) SheetAction(c.nome, c.nome, icon: CupertinoIcons.videocam_fill)],
    );
    if (c == null) return;
    setState(() => _camera = c);
    try {
      await (await SharedPreferences.getInstance()).setString('camera', c);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cfg = ref.watch(configProvider).value ?? const ConfigMidia();
    final o = (ref.watch(estadoProvider).value ?? const EstadoMidia()).obs;
    final msgs = ref.watch(mensagensProvider).value ?? const <Mensagem>[];
    final cam = cfg.cameras.where((c) => c.nome == _camera).firstOrNull;
    if (cfg.cameras.isEmpty) {
      return const AppScaffold(
        title: 'Câmera',
        slivers: [
          SliverToBoxAdapter(
            child: EmptyState(
              icon: CupertinoIcons.videocam,
              title: 'Nenhuma câmera configurada',
              message: 'A liderança de mídia liga cada câmera a uma fonte do OBS em Ajustes.',
            ),
          ),
        ],
      );
    }
    final tally = cam?.tally(o) ?? Tally.livre;
    if (_anterior != tally && tally == Tally.programa) {
      unawaited(HapticFeedback.heavyImpact());
    }
    _anterior = tally;
    final ultima = msgs.where((m) => m.para == Destino.todos || m.para == Destino.cameras).lastOrNull;
    final cor = cam == null ? context.pal.background : tally.cor(context.pal);
    return Scaffold(
      backgroundColor: cor,
      body: SafeArea(
        child: Tappable(
          onTap: () => _escolher(cfg),
          pressedOpacity: .9,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            color: cor,
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Text(
                  cam == null ? 'Toque para escolher a sua câmera' : cam.nome.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: brandFont, fontSize: 30, color: Colors.white70, letterSpacing: 2),
                ),
                if (cam != null)
                  FittedBox(
                    child: Text(
                      tally.label,
                      style: const TextStyle(
                        fontFamily: brandFont,
                        fontSize: 120,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ),
                if (cam != null && o.programa != null)
                  Text('No ar: ${o.programa}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const Spacer(),
                if (ultima != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      children: [
                        Text(
                          ultima.texto,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        Text(ultima.nome, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                const SizedBox(height: 70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
