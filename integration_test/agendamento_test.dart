import 'package:agenda_pastoral/app.dart';
import 'package:agenda_pastoral/data/seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

/// Testes de ponta a ponta com Patrol (rodam no emulador/celular ou Chrome):
///   patrol test -t integration_test/agendamento_test.dart
void main() {
  DateTime clock() => DateTime(2026, 10, 5, 8);

  patrolTest('irmã da Zona Norte não consegue marcar logo após visita na Zona Sul', ($) async {
    await $.pumpWidgetAndSettle(AgendaApp.demo(store: demoStore(clock: clock)));

    await $(#entrarComoMembro).tap();
    await $(#seletorMembro).tap();
    await $('Irmã Maria — Santana · Zona Norte').tap();
    await $(#dia_0).tap();

    // Das 18h às 19h30 não dá tempo de atravessar a cidade.
    expect($(#horario_1800).$('Disponível · toque para reservar'), findsNothing);
    expect($(#horario_1800).$(RegExp('O pastor sai de Santo Amaro')), findsOneWidget);

    await $(#horario_1930).scrollTo().tap();
    await $(#confirmarReserva).tap();
    expect($('Pedido enviado! O pastor foi notificado.'), findsOneWidget);
  });

  patrolTest('pastor recebe a notificação e confirma a visita', ($) async {
    final store = demoStore(clock: clock);
    final pedro = demoMembers[2];
    await store.book(
      pedro,
      store.slotsFor(pedro, store.openDays.first).firstWhere((s) => s.available),
    );

    await $.pumpWidgetAndSettle(AgendaApp.demo(store: store));
    await $(#entrarComoPastor).tap();

    await $(#notificacoes).tap();
    expect($(RegExp('Nova visita: Irmão Pedro')), findsOneWidget);
    await $.tester.tapAt(const Offset(10, 10));
    await $.pumpAndSettle();

    await $(#abaVisitas).tap();
    final visita = store.visits.firstWhere((v) => v.member.id == pedro.id);
    await $(Key('confirmar_${visita.id}')).tap();
    expect($(Key('confirmar_${visita.id}')), findsNothing);
  });
}
