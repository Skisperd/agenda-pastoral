import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../roles.dart';
import 'palette.dart';

/// Símbolo da Pedras Vivas (cruz sobre blocos), desenhado em vetor a partir do logo.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.height = 48});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: height * 570 / 855,
    child: CustomPaint(painter: _MarkPainter()),
  );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 570, sy = size.height / 855;
    Rect r(double l, double t, double w, double h) => Rect.fromLTWH(l * sx, t * sy, w * sx, h * sy);
    final radius = Radius.circular(100 * sx);
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndCorners(Offset.zero & size, topLeft: radius, bottomRight: radius));
    final navy = Paint()..color = Brand.navy;
    final blue = Paint()..color = Brand.blue;
    final stone = Paint()..color = Brand.stone;
    canvas
      ..drawRect(r(0, 0, 250, 247), navy)
      ..drawRect(r(0, 322, 250, 247), blue)
      ..drawRect(r(0, 569, 250, 286), navy)
      ..drawRect(r(324, 0, 246, 247), blue)
      ..drawRect(r(324, 322, 246, 247), navy)
      ..drawRect(r(324, 569, 246, 286), blue)
      ..drawRect(r(250, 0, 74, 855), stone)
      ..drawRect(r(0, 247, 570, 75), stone);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Ícone do app: o símbolo sobre fundo papel, em "squircle".
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, this.size = 88});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Brand.paper,
      borderRadius: BorderRadius.circular(size * .23),
      boxShadow: [
        BoxShadow(color: Brand.navy.withValues(alpha: .18), blurRadius: size * .25, offset: Offset(0, size * .08)),
      ],
    ),
    alignment: Alignment.center,
    child: BrandMark(height: size * .6),
  );
}

/// Ícone e cor de cada perfil de acesso.
extension RoleStyle on AppRole {
  IconData get symbol => switch (this) {
    AppRole.admin => CupertinoIcons.star_fill,
    AppRole.pastor => CupertinoIcons.book_fill,
    AppRole.presbitero => CupertinoIcons.shield_lefthalf_fill,
    AppRole.liderDiaconia => CupertinoIcons.person_crop_rectangle_fill,
    AppRole.diacono => CupertinoIcons.hand_raised_fill,
    AppRole.membro => CupertinoIcons.person_fill,
    AppRole.pending => CupertinoIcons.hourglass,
  };

  Color get tint => switch (this) {
    AppRole.admin => Brand.navy,
    AppRole.pastor => const Color(0xFFA2845E),
    AppRole.presbitero => const Color(0xFF5856D6),
    AppRole.liderDiaconia => const Color(0xFF248A3D),
    AppRole.diacono => const Color(0xFF34C759),
    AppRole.membro => Brand.blue,
    AppRole.pending => const Color(0xFFFF9500),
  };
}

/// Ícone e cor de cada função da escala diaconal.
extension FuncaoDiaconalStyle on FuncaoDiaconal {
  IconData get icon => switch (this) {
    FuncaoDiaconal.recepcao => CupertinoIcons.hand_raised_fill,
    FuncaoDiaconal.acolhimento => CupertinoIcons.person_badge_plus_fill,
    FuncaoDiaconal.ofertorio => CupertinoIcons.gift_fill,
    FuncaoDiaconal.ceia => CupertinoIcons.drop_fill,
    FuncaoDiaconal.estacionamento => CupertinoIcons.car_fill,
    FuncaoDiaconal.seguranca => CupertinoIcons.lock_shield_fill,
    FuncaoDiaconal.apoio => CupertinoIcons.mic_fill,
  };

  Color color(Palette p) => switch (this) {
    FuncaoDiaconal.recepcao => Brand.blue,
    FuncaoDiaconal.acolhimento => p.green,
    FuncaoDiaconal.ofertorio => p.orange,
    FuncaoDiaconal.ceia => p.red,
    FuncaoDiaconal.estacionamento => p.gray,
    FuncaoDiaconal.seguranca => Brand.navy,
    FuncaoDiaconal.apoio => p.purple,
  };
}

/// Ícone e cor de cada ofício.
extension OficioStyle on Oficio {
  IconData get icon => switch (this) {
    Oficio.pastor => CupertinoIcons.book_fill,
    Oficio.presbitero => CupertinoIcons.shield_lefthalf_fill,
    Oficio.diacono => CupertinoIcons.hand_raised_fill,
  };

  Color get tint => switch (this) {
    Oficio.pastor => const Color(0xFFA2845E),
    Oficio.presbitero => const Color(0xFF5856D6),
    Oficio.diacono => const Color(0xFF34C759),
  };
}

/// Avatar com as iniciais do nome, em cor estável por pessoa.
class Initials extends StatelessWidget {
  const Initials(this.name, {super.key, this.size = 36});
  final String name;
  final double size;

  static const _colors = [
    Color(0xFF4B62A4),
    Color(0xFF223776),
    Color(0xFF7187C0),
    Color(0xFF248A3D),
    Color(0xFFA2845E),
    Color(0xFF5856D6),
    Color(0xFFC9566E),
    Color(0xFF30B0C7),
  ];

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final text = parts.isEmpty
        ? '?'
        : parts.length == 1
        ? parts.first[0]
        : '${parts.first[0]}${parts.last[0]}';
    final c = _colors[name.hashCode.abs() % _colors.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(c, Colors.white, .15)!, c],
        ),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: size * .38, height: 1),
      ),
    );
  }
}
