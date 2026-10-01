import 'package:flutter/material.dart';

import '../data/agenda_store.dart';
import '../domain/models.dart';
import '../domain/scheduler.dart';
import 'format.dart';

/// Tela do membro: escolhe o dia e vê só os horários que cabem para ele.
class MemberPage extends StatefulWidget {
  const MemberPage({super.key, required this.store, this.member, this.extraActions = const []});

  final AgendaStore store;

  /// Membro logado. Quando nulo (modo demonstração), aparece um seletor de membro.
  final Member? member;
  final List<Widget> extraActions;

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  late Member? _member = widget.member;
  DateTime? _day;
  bool _showBlocked = true;

  AgendaStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final days = store.openDays;
        final day = _day ?? (days.isEmpty ? null : days.first);
        return Scaffold(
          appBar: AppBar(title: const Text('Agenda do pastor'), actions: widget.extraActions),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                key: const Key('listaAgenda'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (widget.member == null)
                    _memberPicker()
                  else
                    Text(
                      'Olá, ${widget.member!.name}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  if (_member != null) ...[
                    const SizedBox(height: 20),
                    ..._myVisits(_member!),
                    Text('Escolha o dia', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (days.isEmpty)
                      const Text('O pastor ainda não abriu dias para visitas.')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (i, d) in days.indexed)
                            ChoiceChip(
                              key: Key('dia_$i'),
                              label: Text(dayLabel(d)),
                              selected: d == day,
                              onSelected: (_) => setState(() => _day = d),
                            ),
                        ],
                      ),
                    if (day != null) ..._slots(_member!, day),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _memberPicker() {
    return DropdownMenu<Member>(
      key: const Key('seletorMembro'),
      expandedInsets: EdgeInsets.zero,
      label: const Text('Quem é você? (simula o login)'),
      onSelected: (m) => setState(() => _member = m),
      dropdownMenuEntries: [
        for (final m in store.members)
          DropdownMenuEntry(
            value: m,
            label: m.name,
            labelWidget: Text('${m.name} — ${m.neighborhood}'),
          ),
      ],
    );
  }

  List<Widget> _myVisits(Member member) {
    final mine = store.visitsOf(member);
    if (mine.isEmpty) return const [];
    return [
      Text('Minhas visitas', style: Theme.of(context).textTheme.titleMedium),
      for (final v in mine)
        Card(
          child: ListTile(
            leading: Icon(
              v.status == VisitStatus.confirmed
                  ? Icons.check_circle_outline
                  : Icons.hourglass_empty,
            ),
            title: Text('${fullDay(v.start)} · ${range(v.start, v.end)}'),
            subtitle: Text(
              v.status == VisitStatus.confirmed
                  ? 'Confirmada pelo pastor'
                  : 'Aguardando confirmação do pastor',
            ),
            trailing: TextButton(
              onPressed: () => _run(() => store.cancel(v), 'Visita cancelada.'),
              child: const Text('Cancelar'),
            ),
          ),
        ),
      const SizedBox(height: 20),
    ];
  }

  List<Widget> _slots(Member member, DateTime day) {
    final slots = store.slotsFor(member, day);
    final free = slots.where((s) => s.available).length;
    final shown = _showBlocked ? slots : slots.where((s) => s.available).toList();
    return [
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: Text(
              '${fullDay(day)} · $free horário${free == 1 ? '' : 's'} livre${free == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
      SwitchListTile(
        key: const Key('mostrarIndisponiveis'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Mostrar horários indisponíveis e o motivo'),
        subtitle: const Text('Ligado só no protótipo, para entender a regra'),
        value: _showBlocked,
        onChanged: (v) => setState(() => _showBlocked = v),
      ),
      if (shown.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Nenhum horário disponível neste dia.'),
        ),
      for (final s in shown) _SlotTile(slot: s, onBook: () => _confirm(member, s)),
    ];
  }

  Future<void> _confirm(Member member, SlotOption slot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pedir visita'),
        content: Text(
          '${fullDay(slot.start)}, das ${range(slot.start, slot.end)}.\n\n'
          'O pastor será notificado.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
          FilledButton(
            key: const Key('confirmarReserva'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await store.book(member, slot);
      messenger.showSnackBar(
        const SnackBar(content: Text('Pedido enviado! O pastor foi notificado.')),
      );
    } on StateError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível reservar: ${e.message}')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível reservar: $e')));
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Não foi possível concluir: $e')));
    }
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({required this.slot, required this.onBook});

  final SlotOption slot;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = range(slot.start, slot.end);
    return Card(
      key: Key('horario_${hhmm(slot.start).replaceAll(':', '')}'),
      color: slot.available ? colors.primaryContainer : colors.surfaceContainerHighest,
      child: ListTile(
        enabled: slot.available,
        leading: Icon(slot.available ? Icons.event_available : Icons.block),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(slot.blockedReason ?? 'Disponível · toque para reservar'),
        onTap: slot.available ? onBook : null,
      ),
    );
  }
}
