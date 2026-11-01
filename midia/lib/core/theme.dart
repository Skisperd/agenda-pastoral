import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ui/palette.dart';

/// No iPhone/Mac nativos usa a SF Pro do sistema; na web e no Android, Inter.
String? get _uiFont =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS)
    ? null
    : 'Inter';

/// Fonte condensada da identidade visual (títulos e números de destaque).
const brandFont = 'BarlowCondensed';

/// Serifa elegante dos títulos (padrão estúdio).
const serifFont = 'CormorantGaramond';

/// Números, horários e atalhos.
const numFont = 'JetBrainsMono';

/// Rótulo em maiúsculas espaçadas ("ORDEM DE CULTO").
TextStyle trackedLabel(Color color, {double size = 11.5}) =>
    TextStyle(fontSize: size, fontWeight: FontWeight.w600, letterSpacing: size * .2, color: color, height: 1.2);

ThemeData buildTheme(Brightness brightness) {
  final pal = brightness == Brightness.dark ? Palette.dark : Palette.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.navy,
    brightness: brightness,
    primary: pal.accent,
    onPrimary: pal.onAccent,
    surface: pal.card,
    error: pal.red,
  );

  // Escala tipográfica do iOS (Large Title 34 … Caption 2 11).
  TextStyle s(double size, FontWeight w, {double ls = 0, Color? c, double? h}) => TextStyle(
    fontFamily: _uiFont,
    fontSize: size,
    fontWeight: w,
    letterSpacing: ls,
    height: h,
    color: c ?? pal.label,
  );
  final text = TextTheme(
    displaySmall: s(34, FontWeight.w700, ls: -.8, h: 1.12), // Large Title
    headlineMedium: s(28, FontWeight.w700, ls: -.6), // Title 1
    headlineSmall: s(22, FontWeight.w700, ls: -.4), // Title 2
    titleLarge: s(20, FontWeight.w600, ls: -.3), // Title 3
    titleMedium: s(17, FontWeight.w600, ls: -.25), // Headline
    titleSmall: s(15, FontWeight.w600, ls: -.15),
    bodyLarge: s(17, FontWeight.w400, ls: -.25, h: 1.3), // Body
    bodyMedium: s(15, FontWeight.w400, ls: -.15, h: 1.3, c: pal.secondaryLabel), // Subheadline
    bodySmall: s(13, FontWeight.w400, ls: -.05, c: pal.secondaryLabel), // Footnote
    labelLarge: s(17, FontWeight.w600, ls: -.25), // botões
    labelMedium: s(12, FontWeight.w500, c: pal.secondaryLabel), // Caption 1
    labelSmall: s(11, FontWeight.w500, ls: .1, c: pal.secondaryLabel), // Caption 2
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: _uiFont,
    textTheme: text,
    scaffoldBackgroundColor: pal.background,
    canvasColor: pal.background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: pal.fill,
    hoverColor: pal.fill.withValues(alpha: .5),
    dividerTheme: DividerThemeData(color: pal.separator, thickness: .5, space: .5),
    extensions: [pal],
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {for (final p in TargetPlatform.values) p: const CupertinoPageTransitionsBuilder()},
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: pal.accent,
      selectionColor: pal.accent.withValues(alpha: .25),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: InputBorder.none,
      hintStyle: text.bodyLarge?.copyWith(color: pal.tertiaryLabel),
      isDense: true,
      contentPadding: EdgeInsets.zero,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brightness == Brightness.dark ? const Color(0xFF16181C) : const Color(0xF21C1C1E),
      contentTextStyle: s(15, FontWeight.w500, c: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: pal.background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: pal.tertiaryLabel,
      dragHandleSize: const Size(36, 5),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: pal.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      textStyle: text.bodyLarge,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(pal.card),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: pal.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: pal.accent,
      scaffoldBackgroundColor: pal.background,
      barBackgroundColor: pal.bar,
      textTheme: CupertinoTextThemeData(
        primaryColor: pal.accent,
        textStyle: s(17, FontWeight.w400, ls: -.25),
        actionTextStyle: s(17, FontWeight.w400, ls: -.25, c: pal.accent),
        navTitleTextStyle: s(17, FontWeight.w600, ls: -.25),
        navLargeTitleTextStyle: s(34, FontWeight.w700, ls: -.8),
        navActionTextStyle: s(17, FontWeight.w400, ls: -.25, c: pal.accent),
        tabLabelTextStyle: s(10, FontWeight.w500, ls: .1),
        dateTimePickerTextStyle: s(21, FontWeight.w400, ls: -.3),
      ),
    ),
  );
}
