import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/roles.dart';
import '../../core/share.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models/conteudo.dart';
import '../../data/models/escala.dart';
import '../../data/models/pastoral.dart';
import '../../data/models/people.dart';
import '../../data/providers.dart';
import '../common.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final role = ref.watch(roleProvider);
    final today = ref.watch(todayProvider);
    final now = DateTime.now();
    final monday = weekStart(today);
    final semana = ref.watch(weekAgendaProvider(monday));
    final proxima = [
      ...semana,
      ...ref.watch(weekAgendaProvider(addDays(monday, 7))),
    ].where((i) => (i.end ?? i.start.add(const Duration(hours: 1))).isAfter(now)).firstOrNull;
    final avisos = [
      for (final a in ref.watch(avisosProvider).value ?? const <Aviso>[])
        if (a.pinned && a.visibleOn(ymd(today))) a,
    ];
    final videos = ref.watch(weekVideosProvider);
    final escalas = ref.watch(myEscalasProvider);
    final aniversarios = ref.watch(birthdaysProvider(7));
    final pastores = [
      for (final m in ref.watch(officersProvider).value ?? const <Membro>[])
        if (m.oficio == Oficio.pastor) m,
    ];
    final hour = now.hour;
    final saudacao = hour < 12 ? 'Bom dia' : (hour < 18 ? 'Boa tarde' : 'Boa noite');

    return AppScaffold(
      title: '$saudacao${user == null ? '' : ', ${user.firstName}'}',
      actions: [if (role.isPastoral) _Bell()],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(capitalize(fmtLongDate(ymd(today))), style: context.text.bodyMedium),
          ),
        ),
        if (proxima != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _HeroCard(item: proxima, today: today),
            ),
          ),
        for (final a in avisos)
          SliverToBoxAdapter(
            child: NoticeCard(
              icon: CupertinoIcons.pin_fill,
              title: a.title,
              message: a.body,
              color: context.pal.orange,
              onTap: () => context.go('/mais/avisos'),
            ),
          ),
        if (role.isPastoral) const SliverToBoxAdapter(child: _PastorVisits()),
        if (!role.isPastoral) const SliverToBoxAdapter(child: _MyVisits()),
        if (escalas.isNotEmpty) SliverToBoxAdapter(child: _MinhaEscala(escalas.first)),
        if (videos.isNotEmpty)
          SliverToBoxAdapter(
            child: Section(
              header: 'Vídeos da semana',
              plain: true,
              trailing: NavAction(label: 'Ver todos', onPressed: () => context.go('/mais/videos')),
              children: [
                SizedBox(
                  height: 228,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: videos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (_, i) => VideoCard(videos[i]),
                  ),
                ),
              ],
            ),
          ),
        SliverToBoxAdapter(
          child: Section(
            header: 'Esta semana na igreja',
            trailing: NavAction(label: 'Agenda', onPressed: () => context.go('/agenda')),
            children: [
              for (final i in semana)
                if (!i.start.isBefore(today)) AgendaRow(i, showDay: true),
              if (semana.where((i) => !i.start.isBefore(today)).isEmpty) const ListRow(title: 'Nada mais nesta semana'),
            ],
          ),
        ),
        if (aniversarios.isNotEmpty)
          SliverToBoxAdapter(
            child: Section(
              header: 'Aniversariantes da semana',
              children: [
                for (final (m, d) in aniversarios)
                  ListRow(
                    leading: Initials(m.name),
                    title: m.name,
                    subtitle:
                        '${ymd(d) == ymd(today) ? 'Hoje' : capitalize(fmtShortDate(ymd(d)))}'
                        '${ageOn(m.birthDate, d) == null ? '' : ' · ${ageOn(m.birthDate, d)} anos'}',
                    trailing: m.phone == null
                        ? null
                        : TintButton(
                            label: 'Parabéns',
                            icon: CupertinoIcons.gift_fill,
                            onPressed: () => openWhatsApp(
                              context,
                              m.phone!,
                              text:
                                  'Feliz aniversário, ${m.name.split(' ').first}! '
                                  'Que o Senhor te abençoe e te guarde. (Nm 6.24)',
                            ),
                          ),
                    onTap: () => context.go('/pessoas/${m.id}'),
                  ),
              ],
            ),
          ),
        if (pastores.isNotEmpty)
          SliverToBoxAdapter(
            child: Section(
              header: 'Fale com o pastor',
              trailing: NavAction(label: 'Contatos', onPressed: () => context.go('/pessoas')),
              children: [for (final p in pastores) ContactRow(p)],
            ),
          ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.item, required this.today});
  final ItemAgenda item;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final quando = ymd(item.start) == ymd(today)
        ? 'Hoje'
        : ymd(item.start) == ymd(addDays(today, 1))
        ? 'Amanhã'
        : capitalize(fmtShortDate(ymd(item.start)));
    return Tappable(
      onTap: () => item.eventId == null ? context.go('/agenda') : context.push('/agenda/evento/${item.eventId}'),
      pressedOpacity: .85,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: Brand.heroGradient, borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PRÓXIMO NA IGREJA', style: trackedLabel(Colors.white.withValues(alpha: .7))),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      letterSpacing: -.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ['$quando às ${fmtHour(item.start)}', ?item.place].join(' · '),
                    style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 15),
                  ),
                ],
              ),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(weekdayShort[item.start.weekday - 1].toUpperCase(), style: trackedLabel(Brand.gold, size: 11)),
                  Text(
                    '${item.start.day}',
                    style: const TextStyle(
                      fontFamily: brandFont,
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = (ref.watch(notificationsProvider).value ?? const <Notificacao>[]).where((n) => !n.read).length;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        NavAction(icon: CupertinoIcons.bell, tooltip: 'Avisos', onPressed: () => showNotifications(context, ref)),
        if (unread > 0)
          Positioned(
            right: -4,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: context.pal.red, borderRadius: BorderRadius.circular(99)),
              child: Text(
                '$unread',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

/// Avisos do pastor (visitas novas, cancelamentos, pedidos reservados).
Future<void> showNotifications(BuildContext context, WidgetRef ref) async {
  final list = ref.read(notificationsProvider).value ?? const <Notificacao>[];
  await showSheet<void>(
    context,
    tall: true,
    builder: (c) => Column(
      children: [
        const SheetHeader(title: 'Avisos', cancel: 'Fechar'),
        Expanded(
          child: list.isEmpty
              ? const EmptyState(icon: CupertinoIcons.bell_slash, title: 'Nenhum aviso')
              : ListView(
                  children: [
                    Section(
                      children: [
                        for (final n in list.take(50))
                          ListRow(
                            leading: Icon(
                              n.read ? CupertinoIcons.bell : CupertinoIcons.bell_fill,
                              color: n.read ? c.pal.tertiaryLabel : c.pal.accent,
                            ),
                            title: n.message,
                            subtitle: n.createdAt.isEmpty ? null : fmtDateTime(n.createdAt),
                            onTap: n.route == null
                                ? null
                                : () {
                                    Navigator.pop(c);
                                    context.go(n.route!);
                                  },
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
  await ref.read(repoProvider).markNotificationsRead(list);
}

class _PastorVisits extends ConsumerWidget {
  const _PastorVisits();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ymd(ref.watch(todayProvider));
    final visits = ref.watch(visitsProvider).value ?? const <Visita>[];
    final hoje = [
      for (final v in visits)
        if (v.day == today && v.status.active) v,
    ];
    final pendentes = visits.where((v) => v.status == VisitaStatus.pendente && v.day.compareTo(today) >= 0).length;
    return Column(
      children: [
        if (pendentes > 0)
          NoticeCard(
            icon: CupertinoIcons.clock_fill,
            title: pendentes == 1 ? '1 visita aguardando confirmação' : '$pendentes visitas aguardando confirmação',
            color: context.pal.orange,
            onTap: () => context.go('/pastoral'),
          ),
        Section(
          header: 'Visitas de hoje',
          trailing: NavAction(label: 'Agenda pastoral', onPressed: () => context.go('/pastoral')),
          children: [
            for (final v in hoje)
              ListRow(
                leading: Initials(v.memberName),
                title: v.memberName,
                subtitle: '${fmtHour(v.start)}–${fmtHour(v.end)} · ${v.neighborhood}',
                value: v.status == VisitaStatus.pendente ? 'a confirmar' : null,
                onTap: () => context.go('/pastoral'),
              ),
            if (hoje.isEmpty) const ListRow(title: 'Nenhuma visita hoje'),
          ],
        ),
      ],
    );
  }
}

class _MyVisits extends ConsumerWidget {
  const _MyVisits();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final mine = [
      for (final v in ref.watch(visitsProvider).value ?? const <Visita>[])
        if (v.status.active && v.end.isAfter(now)) v,
    ];
    if (mine.isEmpty) {
      return NoticeCard(
        icon: CupertinoIcons.house_fill,
        title: 'Receba uma visita pastoral',
        message: 'Veja os horários em que o pastor consegue chegar até você.',
        color: context.pal.accent,
        onTap: () => context.go('/pastoral'),
      );
    }
    final v = mine.first;
    return NoticeCard(
      icon: CupertinoIcons.house_fill,
      title: 'Visita pastoral: ${capitalize(fmtShortDate(v.day))} às ${fmtHour(v.start)}',
      message: v.status.label,
      color: v.status == VisitaStatus.confirmada ? context.pal.green : context.pal.orange,
      onTap: () => context.go('/pastoral'),
    );
  }
}

class _MinhaEscala extends ConsumerWidget {
  const _MinhaEscala(this.e);
  final EscalaDiaconal e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberId = ref.watch(currentUserProvider).value?.memberId;
    final f = memberId == null ? null : e.funcaoOf(memberId);
    final resp = memberId == null ? null : e.confirmations[memberId];
    return Section(
      header: 'Minha escala',
      trailing: NavAction(label: 'Escala', onPressed: () => context.go('/mais/escala')),
      children: [
        ListRow(
          leading: f == null ? null : IconTile(f.icon, color: f.color(context.pal)),
          title: '${capitalize(fmtShortDate(e.date))}${e.time == null ? '' : ' às ${e.time}'} · ${e.title}',
          subtitle: [?f?.label, resp?.status.label ?? 'Confirme sua presença'].join(' · '),
          onTap: () => context.push('/mais/escala/${e.id}'),
        ),
      ],
    );
  }
}
