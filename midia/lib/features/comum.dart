import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/modelos.dart';

extension TallyStyle on Tally {
  Color cor(Palette p) => switch (this) {
    Tally.programa => const Color(0xFFE5292E),
    Tally.previa => const Color(0xFF2FB34A),
    Tally.livre => p.elevated,
  };
}

/// "1:02:05" a partir de milissegundos.
String duracao(int ms) {
  final s = ms ~/ 1000, h = s ~/ 3600, m = (s % 3600) ~/ 60, ss = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(ss)}' : '$m:${two(ss)}';
}

/// Selo de estado (ponto colorido + texto).
class Sinal extends StatelessWidget {
  const Sinal(this.texto, {super.key, required this.cor, this.piscar = false});
  final String texto;
  final Color cor;
  final bool piscar;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: cor.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.circle_fill, size: 9, color: cor),
        const SizedBox(width: 6),
        Text(
          texto,
          style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 12.5, letterSpacing: .3),
        ),
      ],
    ),
  );
}

/// Miniatura do programa do OBS (data URL JPEG).
class MiniaturaObs extends StatelessWidget {
  const MiniaturaObs({super.key, required this.imagem, required this.cena, this.em});
  final String? imagem;
  final String? cena;
  final String? em;

  @override
  Widget build(BuildContext context) {
    final bytes = imagem == null || !imagem!.contains(',') ? null : base64Decode(imagem!.split(',').last);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: Colors.black),
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
            else
              Center(
                child: Text(
                  cena ?? 'Sem imagem',
                  style: const TextStyle(fontFamily: brandFont, color: Colors.white54, fontSize: 28),
                ),
              ),
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFE5292E), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  'PROGRAMA${cena == null ? '' : ' · $cena'}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
