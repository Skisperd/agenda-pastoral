import 'package:agenda_pastoral/app.dart';
import 'package:agenda_pastoral/data/seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mesmo fluxo do teste Patrol, rodando sem dispositivo (`flutter test`).
void main() {
  testWidgets('membro da Zona Norte reserva e o pastor é notificado', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final store = demoStore(clock: () => DateTime(2026, 10, 5, 8));
    await tester.pumpWidget(AgendaApp.demo(store: store));

    await tester.tap(find.byKey(const Key('entrarComoMembro')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seletorMembro')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Irmã Maria').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dia_0')));
    await tester.pumpAndSettle();

    // 18:00 bloqueado: o pastor está saindo da Zona Sul.
    expect(find.textContaining('O pastor sai de Santo Amaro'), findsWidgets);

    final slot1930 = find.byKey(const Key('horario_1930'));
    await tester.scrollUntilVisible(
      slot1930,
      200,
      scrollable: find
          .descendant(of: find.byKey(const Key('listaAgenda')), matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(slot1930);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmarReserva')));
    await tester.pumpAndSettle();

    expect(find.text('Pedido enviado! O pastor foi notificado.'), findsOneWidget);
    expect(store.unreadCount, 1);

    // Pastor vê a notificação e confirma a visita.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('entrarComoPastor')));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget); // badge

    await tester.tap(find.byKey(const Key('notificacoes')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nova visita: Irmã Maria'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(store.unreadCount, 0);

    await tester.tap(find.byKey(const Key('abaVisitas')));
    await tester.pumpAndSettle();
    final pendente = store.visits.firstWhere((v) => v.member.name == 'Irmã Maria');
    await tester.tap(find.byKey(Key('confirmar_${pendente.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('confirmar_${pendente.id}')), findsNothing);
  });
}
