import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  static const _dest = [
    (CupertinoIcons.house, CupertinoIcons.house_fill, 'Início'),
    (CupertinoIcons.calendar, CupertinoIcons.calendar_today, 'Agenda'),
    (CupertinoIcons.house_alt, CupertinoIcons.house_alt_fill, 'Pastoral'),
    (CupertinoIcons.person_2, CupertinoIcons.person_2_fill, 'Pessoas'),
    (CupertinoIcons.square_grid_2x2, CupertinoIcons.square_grid_2x2_fill, 'Mais'),
  ];

  void _go(int i) {
    HapticFeedback.selectionClick();
    shell.goBranch(i, initialLocation: i == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final demo = ref.watch(isDemoProvider);
    final body = Column(
      children: [
        if (demo) const _DemoBanner(),
        Expanded(
          child: demo ? MediaQuery.removePadding(context: context, removeTop: true, child: shell) : shell,
        ),
      ],
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(index: shell.currentIndex, onTap: _go, items: _dest),
            Container(width: .5, color: context.pal.separator),
            Expanded(
              child: Column(
                children: [
                  const _StudioTopBar(),
                  Expanded(
                    child: MediaQuery.removePadding(context: context, removeTop: true, child: body),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: _GlassTabBar(index: shell.currentIndex, onTap: _go, items: _dest),
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: context.pal.orange.withValues(alpha: .14),
    padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 6, 16, 6),
    child: Text(
      'Modo demonstração · alterações não são salvas',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.pal.orange),
    ),
  );
}

typedef _Item = (IconData, IconData, String);

class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.index, required this.onTap, required this.items});
  final int index;
  final ValueChanged<int> onTap;
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: pal.bar,
            border: Border(top: BorderSide(color: pal.separator, width: .5)),
          ),
          padding: EdgeInsets.only(bottom: bottom > 0 ? bottom - 6 : 4, top: 6),
          child: Row(
            children: [
              for (final (i, (icon, active, label)) in items.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: label,
                    child: Tappable(
                      onTap: () => onTap(i),
                      pressedOpacity: .6,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(i == index ? active : icon, size: 25, color: i == index ? pal.accent : pal.gray),
                          const SizedBox(height: 3),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: i == index ? pal.accent : pal.gray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, required this.onTap, required this.items});
  final int index;
  final ValueChanged<int> onTap;
  final List<_Item> items;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      width: 248,
      color: context.isDark ? const Color(0xFF111113) : const Color(0xFFEDEDEF),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 16, 26),
              child: Row(
                children: [
                  const BrandMark(height: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PEDRAS VIVAS',
                          style: TextStyle(
                            fontFamily: brandFont,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            height: 1,
                            letterSpacing: .6,
                            color: context.isDark ? pal.label : Brand.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('Igreja Presbiteriana', style: context.text.labelMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final (i, (icon, active, label)) in items.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
                child: Semantics(
                  button: true,
                  selected: i == index,
                  label: label,
                  child: Tappable(
                    onTap: () => onTap(i),
                    pressedOpacity: .7,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: i == index ? pal.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(i == index ? active : icon, size: 20, color: i == index ? pal.onAccent : pal.accent),
                          const SizedBox(width: 12),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: i == index ? pal.onAccent : pal.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Barra superior no computador: próxima atividade da igreja + relógio ao vivo.
class _StudioTopBar extends ConsumerStatefulWidget {
  const _StudioTopBar();

  @override
  ConsumerState<_StudioTopBar> createState() => _StudioTopBarState();
}

class _StudioTopBarState extends ConsumerState<_StudioTopBar> {
  late final Timer _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final now = DateTime.now();
    final monday = weekStart(now);
    final next = [
      ...ref.watch(weekAgendaProvider(monday)),
      ...ref.watch(weekAgendaProvider(addDays(monday, 7))),
    ].where((i) => (i.end ?? i.start.add(const Duration(hours: 1))).isAfter(now)).firstOrNull;
    String two(int n) => n.toString().padLeft(2, '0');
    Widget block(String label, Widget value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: trackedLabel(pal.secondaryLabel, size: 10.5)),
        const SizedBox(height: 4),
        value,
      ],
    );
    return Container(
      height: 72,
      padding: EdgeInsets.fromLTRB(28, MediaQuery.paddingOf(context).top, 24, 0),
      decoration: BoxDecoration(
        color: pal.background,
        border: Border(bottom: BorderSide(color: pal.separator)),
      ),
      child: Row(
        children: [
          Expanded(
            child: block(
              'PRÓXIMO NA IGREJA',
              Text(
                next == null
                    ? 'Nada na agenda'
                    : '${next.title} · ${capitalize(fmtShortDate(ymd(next.start)))} às ${fmtHour(next.start)}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: pal.label),
              ),
            ),
          ),
          const SizedBox(width: 26),
          block(
            'RELÓGIO',
            Text(
              '${two(now.hour)}:${two(now.minute)}:${two(now.second)}',
              style: TextStyle(
                fontFamily: numFont,
                fontSize: 16,
                color: pal.label,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
