import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'links.dart';
import 'theme.dart';
import 'ui/palette.dart';

export 'ui/brand.dart';
export 'ui/palette.dart';

// ============================================================================
// Estrutura de página
// ============================================================================

/// Largura máxima do conteúdo das páginas (telas largas aproveitam até aqui).
const kContentWidth = 1280.0;

/// Largura confortável para formulários e textos longos.
const kFormWidth = 760.0;

/// Número de colunas para grades de cartões, pela largura disponível.
int gridColumns(double width, {double min = 360}) => (width / min).floor().clamp(1, 3);

/// Grade simples de cartões que se adapta à largura (1 coluna no celular).
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 360,
    this.spacing = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: LayoutBuilder(
      builder: (context, box) {
        final cols = gridColumns(box.maxWidth, min: minItemWidth);
        final w = (box.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final c in children) SizedBox(width: w, child: c)],
        );
      },
    ),
  );
}

/// Duas colunas lado a lado em telas largas; empilhadas no celular.
class TwoColumns extends StatelessWidget {
  const TwoColumns({
    super.key,
    required this.left,
    required this.right,
    this.breakpoint = 980,
    this.leftFlex = 3,
    this.rightFlex = 2,
  });
  final Widget left;
  final Widget right;
  final double breakpoint;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => box.maxWidth < breakpoint
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, right])
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: leftFlex, child: left),
              Expanded(flex: rightFlex, child: right),
            ],
          ),
  );
}

/// Página no padrão iOS: barra translúcida com título grande que recolhe ao
/// rolar (ou título compacto em telas de detalhe), conteúdo centralizado em
/// telas largas.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    this.slivers = const [],
    this.actions = const [],
    this.large = true,
    this.leading,
    this.previousPageTitle,
    this.bottomBar,
    this.maxWidth = kContentWidth,
  });

  final String title;
  final List<Widget> slivers;
  final List<Widget> actions;
  final bool large;
  final Widget? leading;
  final String? previousPageTitle;
  final Widget? bottomBar;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final trailing = actions.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, a) in actions.indexed) ...[if (i > 0) const SizedBox(width: 14), a],
            ],
          );
    final border = Border(bottom: BorderSide(color: pal.separator, width: .5));
    final content = [
      // Margem calculada pela área de conteúdo real (sem a barra lateral): centraliza
      // em telas muito largas e mantém um respiro confortável no computador.
      for (final s in slivers)
        SliverLayoutBuilder(
          builder: (context, box) => SliverPadding(
            padding: EdgeInsets.symmetric(
              horizontal: math.max(box.crossAxisExtent >= 900 ? 16.0 : 0.0, (box.crossAxisExtent - maxWidth) / 2),
            ),
            sliver: s,
          ),
        ),
      SliverToBoxAdapter(child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom)),
    ];

    if (large) {
      return Scaffold(
        backgroundColor: pal.background,
        bottomNavigationBar: bottomBar,
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(title),
              leading: leading,
              trailing: trailing,
              previousPageTitle: previousPageTitle,
              backgroundColor: pal.bar,
              border: border,
              transitionBetweenRoutes: false,
              stretch: true,
            ),
            ...content,
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: pal.background,
      extendBodyBehindAppBar: true,
      bottomNavigationBar: bottomBar,
      appBar: CupertinoNavigationBar(
        middle: Text(title, overflow: TextOverflow.ellipsis),
        leading: leading,
        trailing: trailing,
        previousPageTitle: previousPageTitle,
        backgroundColor: pal.bar,
        border: border,
        transitionBetweenRoutes: false,
      ),
      body: Builder(
        builder: (context) => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).top)),
            ...content,
          ],
        ),
      ),
    );
  }
}

/// Ação da barra de navegação (ícone ou texto na cor de destaque).
class NavAction extends StatelessWidget {
  const NavAction({super.key, this.icon, this.label, required this.onPressed, this.bold = false, this.tooltip});
  final IconData? icon;
  final String? label;
  final VoidCallback? onPressed;
  final bool bold;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final color = onPressed == null ? pal.tertiaryLabel : pal.accent;
    Widget child = icon != null
        ? Icon(icon, size: 24, color: color)
        : Text(
            label!,
            style: TextStyle(color: color, fontSize: 17, fontWeight: bold ? FontWeight.w600 : FontWeight.w400),
          );
    if (tooltip != null) child = Tooltip(message: tooltip!, child: child);
    return Tappable(
      onTap: onPressed,
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: child),
    );
  }
}

/// Limita a largura do conteúdo em telas grandes.
class Constrained extends StatelessWidget {
  const Constrained({super.key, required this.child, this.maxWidth = kContentWidth});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

// ============================================================================
// Toques
// ============================================================================

/// Área tocável que esmaece ao pressionar, como os botões do iOS.
class Tappable extends StatefulWidget {
  const Tappable({super.key, required this.child, this.onTap, this.pressedOpacity = .45, this.haptic = false});
  final Widget child;
  final VoidCallback? onTap;
  final double pressedOpacity;
  final bool haptic;

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedOpacity(
        duration: Duration(milliseconds: _down ? 10 : 180),
        opacity: _down ? widget.pressedOpacity : 1,
        child: widget.child,
      ),
    ),
  );
}

/// Área tocável que ganha fundo cinza ao pressionar (linhas de lista).
class _Highlight extends StatefulWidget {
  const _Highlight({required this.child, this.onTap, this.onLongPress});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<_Highlight> createState() => _HighlightState();
}

class _HighlightState extends State<_Highlight> {
  bool _down = false;
  bool _hover = false;

  void _set(bool v) {
    if (widget.onTap != null && v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => enabled ? setState(() => _hover = true) : null,
      onExit: (_) => enabled ? setState(() => _hover = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: Duration(milliseconds: _down ? 0 : 220),
          color: _down
              ? pal.label.withValues(alpha: .07)
              : _hover
              ? pal.label.withValues(alpha: .035)
              : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}

// ============================================================================
// Listas agrupadas
// ============================================================================

/// Seção de lista agrupada com cantos arredondados (inset grouped).
class Section extends StatelessWidget {
  const Section({
    super.key,
    this.header,
    this.footer,
    this.children = const [],
    this.trailing,
    this.dividerIndent,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 0),
    this.plain = false,
  });

  final String? header;
  final String? footer;
  final List<Widget> children;

  /// Ação ao lado do cabeçalho (ex.: "Ver tudo").
  final Widget? trailing;
  final double? dividerIndent;
  final EdgeInsets padding;

  /// Sem fundo de cartão (para conteúdo próprio como carrosséis).
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final indent = dividerIndent ?? (children.any((c) => c is ListRow && c.leading != null) ? 62.0 : 16.0);
    final visible = children.where((c) => c is! SizedBox || c.height != 0).toList();
    return Padding(
      padding: padding.copyWith(top: header == null ? 20 : 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: EdgeInsets.fromLTRB(padding.left == 0 ? 20 : 4, 0, padding.right == 0 ? 20 : 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      header!,
                      style: context.text.titleLarge?.copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
          if (plain)
            ...visible
          else if (visible.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColoredBox(
                color: pal.card,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, c) in visible.indexed) ...[
                      if (i > 0)
                        Padding(
                          padding: EdgeInsets.only(left: indent),
                          child: Container(height: .5, color: pal.separator),
                        ),
                      c,
                    ],
                  ],
                ),
              ),
            ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(footer!, style: context.text.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// Linha de lista do iOS: ícone, título, subtítulo, valor e seta.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    this.leading,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.subtitleWidget,
    this.value,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.chevron,
    this.destructive = false,
    this.accent = false,
    this.maxSubtitleLines = 2,
    this.center = false,
  });

  final Widget? leading;
  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? subtitleWidget;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool? chevron;
  final bool destructive;
  final bool accent;
  final int maxSubtitleLines;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final t = context.text;
    final showChevron = chevron ?? (onTap != null && !destructive && !accent && trailing == null);
    final titleColor = destructive
        ? pal.red
        : accent
        ? pal.accent
        : pal.label;
    final hasSub = subtitle != null || subtitleWidget != null;
    return _Highlight(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 46),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, hasSub ? 10 : 11, showChevron ? 12 : 16, hasSub ? 10 : 11),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    titleWidget ??
                        Text(
                          title ?? '',
                          style: t.bodyLarge?.copyWith(color: titleColor, height: 1.2),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    if (hasSub) const SizedBox(height: 2),
                    subtitleWidget ??
                        (subtitle == null
                            ? const SizedBox.shrink()
                            : Text(
                                subtitle!,
                                style: t.bodyMedium?.copyWith(fontSize: 14),
                                maxLines: maxSubtitleLines,
                                overflow: TextOverflow.ellipsis,
                              )),
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(value!, style: t.bodyLarge?.copyWith(color: pal.secondaryLabel)),
              ],
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
              if (showChevron) ...[
                const SizedBox(width: 6),
                Icon(CupertinoIcons.chevron_forward, size: 16, color: pal.tertiaryLabel),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Quadradinho colorido com ícone branco (como nos Ajustes do iOS).
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, required this.color, this.size = 32});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .24),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color.lerp(color, Colors.white, .12)!, color],
      ),
    ),
    child: Icon(icon, color: Colors.white, size: size * .58),
  );
}

/// Número dentro de círculo (posição no repertório, canal de som).
class IndexBadge extends StatelessWidget {
  const IndexBadge(this.n, {super.key, this.size = 28});
  final int n;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: context.pal.fill, shape: BoxShape.circle),
    child: Text(
      '$n',
      style: TextStyle(
        fontFamily: brandFont,
        fontWeight: FontWeight.w700,
        fontSize: size * .55,
        color: context.pal.secondaryLabel,
      ),
    ),
  );
}

// ============================================================================
// Selos e botões
// ============================================================================

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color, this.icon, this.solid = false});
  final String label;
  final Color? color;
  final IconData? icon;
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pal.secondaryLabel;
    final fg = solid ? Colors.white : c;
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 9 : 7, 3.5, 9, 3.5),
      decoration: BoxDecoration(
        color: solid ? c : c.withValues(alpha: context.isDark ? .22 : .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: -.05),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão principal em cápsula, largura total.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.icon, this.color, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final bg = color ?? pal.accent;
    final fg = color == null ? pal.onAccent : Colors.white;
    final enabled = onPressed != null && !loading;
    return Tappable(
      onTap: enabled ? onPressed : null,
      haptic: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled || loading ? 1 : .4,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: loading
              ? CupertinoActivityIndicator(color: fg)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, color: fg, size: 20), const SizedBox(width: 8)],
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -.25),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Botão secundário: cápsula com fundo tingido.
class TintButton extends StatelessWidget {
  const TintButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
    this.expand = false,
    this.large = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool expand;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pal.accent;
    final child = Container(
      height: large ? 50 : 34,
      padding: EdgeInsets.symmetric(horizontal: large ? 18 : 13),
      decoration: BoxDecoration(
        color: c.withValues(alpha: context.isDark ? .2 : .1),
        borderRadius: BorderRadius.circular(large ? 14 : 99),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, color: c, size: large ? 20 : 16), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c, fontSize: large ? 17 : 15, fontWeight: FontWeight.w600, letterSpacing: -.2),
            ),
          ),
        ],
      ),
    );
    return Tappable(
      onTap: onPressed,
      child: Opacity(opacity: onPressed == null ? .4 : 1, child: child),
    );
  }
}

/// Botão que abre um link externo.
class LinkButton extends StatelessWidget {
  const LinkButton({super.key, required this.label, required this.url, this.icon});
  final String label;
  final String url;
  final IconData? icon;

  @override
  Widget build(BuildContext context) =>
      TintButton(label: label, icon: icon ?? appIconForUrl(url), onPressed: () => openUrl(context, url));
}

IconData appIconForUrl(String url) {
  final u = url.toLowerCase();
  if (u.contains('youtu')) return CupertinoIcons.play_rectangle_fill;
  if (u.contains('docs.google.com/presentation')) return CupertinoIcons.rectangle_on_rectangle_angled;
  if (u.contains('drive.google') || u.endsWith('.pdf')) return CupertinoIcons.doc_text_fill;
  if (u.contains('spotify') || u.contains('soundcloud')) return CupertinoIcons.headphones;
  if (u.contains('cifraclub')) return CupertinoIcons.music_note_list;
  return CupertinoIcons.link;
}

// ============================================================================
// Estados
// ============================================================================

class AsyncView<T> extends StatelessWidget {
  const AsyncView(this.value, {super.key, required this.builder});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => value.when(
    data: builder,
    loading: () => const Padding(
      padding: EdgeInsets.all(48),
      child: Center(child: CupertinoActivityIndicator(radius: 12)),
    ),
    error: (e, _) => EmptyState(icon: CupertinoIcons.wifi_slash, title: 'Não foi possível carregar', message: '$e'),
  );
}

/// Estado vazio no estilo ContentUnavailableView.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: pal.tertiaryLabel),
          const SizedBox(height: 14),
          Text(
            title,
            style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, style: context.text.bodyMedium, textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

/// Cartão de aviso tingido (alertas na própria tela).
class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.icon, required this.title, this.message, required this.color, this.onTap});
  final IconData icon;
  final String title;
  final String? message;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Tappable(
      onTap: onTap,
      pressedOpacity: .7,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: context.isDark ? .2 : .1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            IconTile(icon, color: color, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.titleMedium),
                  if (message != null) Text(message!, style: context.text.bodyMedium?.copyWith(fontSize: 14)),
                ],
              ),
            ),
            if (onTap != null) Icon(CupertinoIcons.chevron_forward, size: 16, color: color),
          ],
        ),
      ),
    ),
  );
}

// ============================================================================
// Controles
// ============================================================================

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.onChanged, this.placeholder = 'Buscar', this.autofocus = false});
  final ValueChanged<String> onChanged;
  final String placeholder;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => CupertinoSearchTextField(
    placeholder: placeholder,
    onChanged: onChanged,
    autofocus: autofocus,
    backgroundColor: context.pal.fill,
    style: context.text.bodyLarge,
    placeholderStyle: context.text.bodyLarge?.copyWith(color: context.pal.secondaryLabel),
    borderRadius: BorderRadius.circular(11),
  );
}

/// Controle segmentado do iOS.
class Segmented<T extends Object> extends StatelessWidget {
  const Segmented({super.key, required this.value, required this.segments, required this.onChanged});
  final T value;
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: CupertinoSlidingSegmentedControl<T>(
      groupValue: value,
      backgroundColor: context.pal.fill,
      thumbColor: context.isDark ? const Color(0xFF636366) : Colors.white,
      onValueChanged: (v) {
        if (v != null) {
          HapticFeedback.selectionClick();
          onChanged(v);
        }
      },
      children: {
        for (final e in segments.entries)
          e.key: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              e.value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: e.key == value ? FontWeight.w600 : FontWeight.w500,
                color: context.pal.label,
              ),
            ),
          ),
      },
    ),
  );
}

/// Seletor horizontal em cápsulas (abas/filtros).
class ChipBar<T> extends StatelessWidget {
  const ChipBar({super.key, required this.items, required this.selected, required this.onSelected, this.icons});
  final Map<T, String> items;
  final T? selected;
  final ValueChanged<T> onSelected;
  final Map<T, IconData>? icons;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final e in items.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tappable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(e.key);
                },
                pressedOpacity: .7,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: e.key == selected ? pal.label : pal.card,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: e.key == selected ? pal.label : pal.separator, width: .5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icons?[e.key] case final ic?) ...[
                        Icon(ic, size: 15, color: e.key == selected ? pal.background : pal.label),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        e.value,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: e.key == selected ? pal.background : pal.label,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) =>
      CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: context.pal.green);
}

/// Campo de formulário dentro de uma seção (rótulo à esquerda ou placeholder).
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.controller,
    this.label,
    this.placeholder,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.obscure = false,
    this.capitalization = TextCapitalization.none,
    this.autofillHints,
    this.onSubmitted,
    this.labelWidth = 104,
  });

  final TextEditingController controller;
  final String? label;
  final String? placeholder;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final bool autofocus;
  final bool obscure;
  final TextCapitalization capitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: obscure ? 1 : maxLines,
      minLines: minLines,
      autofocus: autofocus,
      obscureText: obscure,
      textCapitalization: capitalization,
      autofillHints: autofillHints,
      onFieldSubmitted: onSubmitted,
      style: context.text.bodyLarge,
      decoration: InputDecoration(
        hintText: placeholder,
        errorStyle: TextStyle(color: context.pal.red, fontSize: 12.5),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: label == null
          ? field
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(label!, style: context.text.bodyLarge),
                ),
                Expanded(child: field),
              ],
            ),
    );
  }
}

// ============================================================================
// Diálogos, folhas e avisos
// ============================================================================

class SheetAction<T> {
  const SheetAction(this.label, this.value, {this.icon, this.destructive = false});
  final String label;
  final T value;
  final IconData? icon;
  final bool destructive;
}

/// Folha de ações do iOS (action sheet).
Future<T?> showActionSheet<T>(
  BuildContext context, {
  String? title,
  String? message,
  required List<SheetAction<T>> actions,
}) => showModalBottomSheet<T>(
  context: context,
  backgroundColor: Colors.transparent,
  showDragHandle: false,
  useSafeArea: true,
  builder: (c) {
    final pal = c.pal;
    Widget group(List<Widget> children) => ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: ColoredBox(
          color: pal.card.withValues(alpha: .94),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, w) in children.indexed) ...[if (i > 0) Container(height: .5, color: pal.separator), w],
            ],
          ),
        ),
      ),
    );
    Widget button(String label, VoidCallback onTap, {Color? color, bool bold = false, IconData? icon}) => _Highlight(
      onTap: onTap,
      child: SizedBox(
        height: 57,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, color: color ?? pal.accent, size: 20), const SizedBox(width: 8)],
              Text(
                label,
                style: TextStyle(
                  fontSize: 19,
                  color: color ?? pal.accent,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Constrained(
        maxWidth: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            group([
              if (title != null || message != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    children: [
                      if (title != null)
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: c.text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      if (message != null) Text(message, textAlign: TextAlign.center, style: c.text.bodySmall),
                    ],
                  ),
                ),
              for (final a in actions)
                button(a.label, () => Navigator.pop(c, a.value), color: a.destructive ? pal.red : null, icon: a.icon),
            ]),
            const SizedBox(height: 8),
            group([button('Cancelar', () => Navigator.pop(c), bold: true)]),
          ],
        ),
      ),
    );
  },
);

/// Alerta no estilo iOS. Retorna o índice da ação escolhida.
Future<bool> confirm(
  BuildContext context,
  String title, {
  String? message,
  String ok = 'Confirmar',
  bool destructive = false,
}) async =>
    await showAppDialog<bool>(
      context,
      title: title,
      message: message,
      actions: [
        const DialogAction('Cancelar', false),
        DialogAction(ok, true, destructive: destructive, primary: !destructive),
      ],
    ) ??
    false;

class DialogAction<T> {
  const DialogAction(this.label, this.value, {this.destructive = false, this.primary = false});
  final String label;
  final T value;
  final bool destructive;
  final bool primary;
}

Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  required List<DialogAction<T>> actions,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: title,
  barrierColor: Colors.black.withValues(alpha: .32),
  transitionDuration: const Duration(milliseconds: 220),
  transitionBuilder: (c, a, _, child) => FadeTransition(
    opacity: a,
    child: ScaleTransition(
      scale: Tween(begin: 1.12, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
  ),
  pageBuilder: (c, _, _) {
    final pal = c.pal;
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Material(
              color: pal.card.withValues(alpha: .96),
              child: SizedBox(
                width: content == null ? 280 : 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                      child: Column(
                        children: [
                          Text(title, textAlign: TextAlign.center, style: c.text.titleMedium),
                          if (message != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: c.text.bodySmall?.copyWith(color: pal.label, fontSize: 13.5),
                            ),
                          ],
                          if (content != null) ...[const SizedBox(height: 14), content],
                        ],
                      ),
                    ),
                    Container(height: .5, color: pal.separator),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (i, a) in actions.indexed) ...[
                            if (i > 0) Container(width: .5, color: pal.separator),
                            Expanded(
                              child: _Highlight(
                                onTap: () => Navigator.pop(c, a.value),
                                child: SizedBox(
                                  height: 46,
                                  child: Center(
                                    child: Text(
                                      a.label,
                                      style: TextStyle(
                                        fontSize: 17,
                                        color: a.destructive ? pal.red : pal.accent,
                                        fontWeight: a.primary ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  },
);

/// Pede um texto (ex.: motivo do pedido de ajustes).
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? message,
  String? placeholder,
  String ok = 'OK',
  bool required = false,
}) async {
  final ctrl = TextEditingController();
  final result = await showAppDialog<bool>(
    context,
    title: title,
    message: message,
    content: CupertinoTextField(
      controller: ctrl,
      autofocus: true,
      maxLines: 4,
      minLines: 2,
      placeholder: placeholder,
      padding: const EdgeInsets.all(10),
      style: context.text.bodyLarge?.copyWith(fontSize: 15),
      decoration: BoxDecoration(color: context.pal.background, borderRadius: BorderRadius.circular(9)),
    ),
    actions: [const DialogAction('Cancelar', false), DialogAction(ok, true, primary: true)],
  );
  final text = ctrl.text.trim();
  ctrl.dispose();
  if (result != true || (required && text.isEmpty)) return null;
  return text;
}

/// Folha modal com cantos arredondados e alça (para formulários e listas).
Future<T?> showSheet<T>(BuildContext context, {required Widget Function(BuildContext) builder, bool tall = false}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (c) => tall ? SizedBox(height: MediaQuery.sizeOf(c).height * .88, child: builder(c)) : builder(c),
    );

/// Cabeçalho de folha: Cancelar · Título · Ação.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key, required this.title, this.action, this.onAction, this.cancel = 'Cancelar'});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final String? cancel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Row(
      children: [
        SizedBox(
          width: 92,
          child: cancel == null
              ? null
              : Align(
                  alignment: Alignment.centerLeft,
                  child: NavAction(label: cancel, onPressed: () => Navigator.pop(context)),
                ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(
          width: 92,
          child: action == null
              ? null
              : Align(
                  alignment: Alignment.centerRight,
                  child: NavAction(label: action, bold: true, onPressed: onAction),
                ),
        ),
      ],
    ),
  );
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
}

/// Executa uma ação assíncrona mostrando o erro, se houver.
Future<bool> guard(BuildContext context, Future<void> Function() action, {String? success}) async {
  try {
    await action();
    if (success != null && context.mounted) {
      unawaited(HapticFeedback.lightImpact());
      toast(context, success);
    }
    return true;
  } catch (e) {
    if (context.mounted) toast(context, 'Erro: $e');
    return false;
  }
}
