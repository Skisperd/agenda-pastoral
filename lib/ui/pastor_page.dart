import 'package:flutter/material.dart';

import '../data/agenda_store.dart';
import '../domain/models.dart';
import 'format.dart';

/// Tela do pastor: janelas de atendimento por semana + visitas recebidas.
class PastorPage extends StatelessWidget {
  const PastorPage({super.key, required this.store, this.extraActions = const []});

  final AgendaStore store;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Área do pastor'),
            actions: [
              IconButton(
                key: const Key('notificacoes'),
                tooltip: 'Notificações',
                icon: Badge.count(
                  count: store.unreadCount,
                  isLabelVisible: store.unreadCount > 0,
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => _showNotifications(context),
              ),
              ...extraActions,
            ],
            bottom: const TabBar(
              tabs: [
                Tab(key: Key('abaDisponibilidade'), text: 'Disponibilidade'),
                Tab(key: Key('abaVisitas'), text: 'Visitas'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('novaJanela'),
            onPressed: () => _addWindow(context),
            icon: const Icon(Icons.add),
            label: const Text('Liberar horário'),
          ),
          body: TabBarView(
            children: [
              _AvailabilityTab(store: store),
              _VisitsTab(store: store),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    final items = store.notifications;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            const ListTile(title: Text('Notificações')),
            if (items.isEmpty) const ListTile(title: Text('Nenhuma notificação ainda.')),
            for (final n in items)
              ListTile(
                leading: Icon(n.read ? Icons.notifications_none : Icons.notifications_active),
                title: Text(n.message),
                subtitle: Text('${ddmm(n.createdAt)} às ${hhmm(n.createdAt)}'),
              ),
          ],
        ),
      ),
    ).then((_) => store.markNotificationsRead());
  }

  Future<void> _addWindow(BuildContext context) async {
    final now = store.clock();
    final date = await showDatePicker(
      context: context,
      helpText: 'Dia da visita',
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 120)),
    );
    if (date == null || !context.mounted) return;
    final start = await showTimePicker(
      context: context,
      helpText: 'Começa às',
      initialTime: const TimeOfDay(hour: 17, minute: 0),
    );
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(
      context: context,
      helpText: 'Termina às',
      initialTime: TimeOfDay(hour: (start.hour + 5).clamp(0, 23), minute: start.minute),
    );
    if (end == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await store.addWindow(
        DateTime(date.year, date.month, date.day, start.hour, start.minute),
        DateTime(date.year, date.month, date.day, end.hour, end.minute),
      );
    } on ArgumentError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${e.message}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível salvar: $e')));
    }
  }
}

class _AvailabilityTab extends StatelessWidget {
  const _AvailabilityTab({required this.store});

  final AgendaStore store;

  @override
  Widget build(BuildContext context) {
    final byWeek = <DateTime, List<AvailabilityWindow>>{};
    for (final w in store.windows) {
      byWeek.putIfAbsent(weekStart(w.start), () => []).add(w);
    }
    if (byWeek.isEmpty) {
      return const Center(child: Text('Toque em "Liberar horário" para abrir sua agenda.'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        for (final MapEntry(key: week, value: windows) in byWeek.entries) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Semana de ${ddmm(week)} a ${ddmm(week.add(const Duration(days: 6)))}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                key: Key('copiarSemana_${ddmm(week)}'),
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Repetir na próxima'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final n = await store.copyWeekToNext(week);
                  messenger.showSnackBar(
                    SnackBar(content: Text('$n horário(s) copiados para a semana seguinte')),
                  );
                },
              ),
            ],
          ),
          for (final w in windows)
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(fullDay(w.start)),
                subtitle: Text('Atende das ${range(w.start, w.end)}'),
                trailing: IconButton(
                  tooltip: 'Remover',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => store.removeWindow(w.id),
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _VisitsTab extends StatelessWidget {
  const _VisitsTab({required this.store});

  final AgendaStore store;

  @override
  Widget build(BuildContext context) {
    final visits = store.visits.where((v) => v.isActive).toList();
    if (visits.isEmpty) return const Center(child: Text('Nenhuma visita marcada.'));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        for (final v in visits)
          Card(
            key: Key('visita_${v.id}'),
            child: ListTile(
              leading: Icon(
                v.status == VisitStatus.confirmed ? Icons.check_circle : Icons.fiber_new_outlined,
              ),
              title: Text('${v.member.name} · ${fullDay(v.start)} ${range(v.start, v.end)}'),
              subtitle: Text('${v.member.neighborhood}\n${v.member.phone}'),
              isThreeLine: true,
              trailing: v.status == VisitStatus.pending
                  ? Wrap(
                      children: [
                        IconButton(
                          key: Key('confirmar_${v.id}'),
                          tooltip: 'Confirmar',
                          icon: const Icon(Icons.check),
                          onPressed: () => store.setVisitStatus(v.id, VisitStatus.confirmed),
                        ),
                        IconButton(
                          tooltip: 'Recusar',
                          icon: const Icon(Icons.close),
                          onPressed: () => store.setVisitStatus(v.id, VisitStatus.cancelled),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}
