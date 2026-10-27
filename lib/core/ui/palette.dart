import 'package:flutter/material.dart';

/// Cores da identidade da Igreja Cristã Presbiteriana Pedras Vivas.
abstract final class Brand {
  static const navy = Color(0xFF223776);
  static const blue = Color(0xFF4B62A4);
  static const lavender = Color(0xFF7187C0);
  static const stone = Color(0xFFDED9D5);
  static const paper = Color(0xFFF4F4F5);

  /// Gradiente das superfícies de destaque (cartão do próximo culto, ícone).
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A4389), navy, Color(0xFF17265A)],
  );

  /// Dourado do destaque (botões principais, ícone ativo).
  static const gold = Color(0xFFD9B06B);
  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE9CA89), Color(0xFFCA924C)],
  );

  /// Brilho dourado em volta de elementos ativos.
  static List<BoxShadow> goldGlow([double strength = 1]) => [
    BoxShadow(color: gold.withValues(alpha: .55 * strength), spreadRadius: .5),
    BoxShadow(color: gold.withValues(alpha: .28 * strength), blurRadius: 24, spreadRadius: -4),
  ];

  /// Brilho azul "técnico" (prévia, seleção).
  static List<BoxShadow> techGlow([double strength = 1]) => [
    BoxShadow(color: const Color(0xFF418DFA).withValues(alpha: .55 * strength), spreadRadius: .5),
    BoxShadow(color: const Color(0xFF418DFA).withValues(alpha: .25 * strength), blurRadius: 24, spreadRadius: -8),
  ];
}

/// Cores semânticas no modelo do iOS (label, secondaryLabel, separator…),
/// com a marca como cor de destaque. Acesse com `context.pal`.
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.background,
    required this.card,
    required this.elevated,
    required this.label,
    required this.secondaryLabel,
    required this.tertiaryLabel,
    required this.separator,
    required this.fill,
    required this.accent,
    required this.onAccent,
    required this.bar,
    required this.red,
    required this.orange,
    required this.yellow,
    required this.green,
    required this.teal,
    required this.blue,
    required this.indigo,
    required this.purple,
    required this.pink,
    required this.gray,
  });

  /// Fundo das telas (systemGroupedBackground).
  final Color background;

  /// Fundo das seções/cartões (secondarySystemGroupedBackground).
  final Color card;

  /// Superfície dentro de cartões (tertiary).
  final Color elevated;
  final Color label;
  final Color secondaryLabel;
  final Color tertiaryLabel;
  final Color separator;

  /// Preenchimento de campos de busca e botões discretos.
  final Color fill;
  final Color accent;
  final Color onAccent;

  /// Barras translúcidas (navegação e abas), usadas com desfoque.
  final Color bar;
  final Color red, orange, yellow, green, teal, blue, indigo, purple, pink, gray;

  static const light = Palette(
    background: Color(0xFFF4F4F5),
    card: Color(0xFFFFFFFF),
    elevated: Color(0xFFF4F4F5),
    label: Color(0xFF0B1024),
    secondaryLabel: Color(0x993C3C43),
    tertiaryLabel: Color(0x4D3C3C43),
    separator: Color(0x333C3C43),
    fill: Color(0x1A767680),
    accent: Brand.navy,
    onAccent: Colors.white,
    bar: Color(0xCCF8F8F9),
    red: Color(0xFFFF3B30),
    orange: Color(0xFFFF9500),
    yellow: Color(0xFFFFCC00),
    green: Color(0xFF34C759),
    teal: Color(0xFF30B0C7),
    blue: Color(0xFF007AFF),
    indigo: Brand.blue,
    purple: Color(0xFFAF52DE),
    pink: Color(0xFFFF2D55),
    gray: Color(0xFF8E8E93),
  );

  /// Padrão "estúdio" (Kairos): grafite quase preto, bordas finas e dourado.
  static const dark = Palette(
    background: Color(0xFF060709),
    card: Color(0xFF0D0E11),
    elevated: Color(0xFF16181C),
    label: Color(0xFFECEFF2),
    secondaryLabel: Color(0xFF83868C),
    tertiaryLabel: Color(0xFF52555B),
    separator: Color(0x14FFFFFF),
    fill: Color(0x0FFFFFFF),
    accent: Brand.gold,
    onAccent: Color(0xFF0D0B07),
    bar: Color(0xE0090A0C),
    red: Color(0xFFFC3651),
    orange: Color(0xFFE59A4C),
    yellow: Color(0xFFE9CA89),
    green: Color(0xFF3AD4AA),
    teal: Color(0xFF3FC3D6),
    blue: Color(0xFF418DFA),
    indigo: Color(0xFF418DFA),
    purple: Color(0xFFA78BFA),
    pink: Color(0xFFF0719F),
    gray: Color(0xFF83868C),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) => t < .5 ? this : (other ?? this);
}

extension PaletteX on BuildContext {
  Palette get pal => Theme.of(this).extension<Palette>()!;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
