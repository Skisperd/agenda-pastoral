import 'package:agenda_pastoral/data/providers.dart';
import 'package:agenda_pastoral/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> pumpApp(WidgetTester tester, {Size size = const Size(420, 900)}) async {
  await initializeDateFormatting('pt_BR');
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await tester.runAsync(demoOverrides);
  await tester.pumpWidget(ProviderScope(overrides: overrides!, child: const IgrejaApp()));
  await tester.pumpAndSettle();
}

Future<void> entrarComo(WidgetTester tester, String perfil) async {
  expect(find.text('Entrar como'), findsOneWidget);
  await tester.tap(find.text(perfil));
  await tester.pumpAndSettle();
}

Future<void> rolarAte(WidgetTester tester, String texto) async {
  final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
  await tester.scrollUntilVisible(find.text(texto), 300, scrollable: vertical.last);
  await tester.pumpAndSettle();
}

Future<void> aba(WidgetTester tester, String nome) async {
  await tester.tap(find.text(nome).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pastor vê a agenda pastoral, pessoas e a escala', (tester) async {
    await pumpApp(tester);
    await entrarComo(tester, 'Pastor');
    await rolarAte(tester, 'Visitas de hoje');
    await rolarAte(tester, 'Esta semana na igreja');

    await aba(tester, 'Pastoral');
    expect(find.text('Agenda pastoral'), findsWidgets);
    await tester.tap(find.text('Horários'));
    await tester.pumpAndSettle();
    expect(find.text('Liberar horário'), findsOneWidget);

    await aba(tester, 'Pessoas');
    await rolarAte(tester, 'Maria Aparecida Santos');
    await tester.tap(find.text('Maria Aparecida Santos'));
    await tester.pumpAndSettle();
    await rolarAte(tester, 'Anotações pastorais');
  });

  testWidgets('membro marca uma visita só nos horários possíveis', (tester) async {
    await pumpApp(tester);
    await entrarComo(tester, 'Membro');
    await aba(tester, 'Pastoral');
    expect(find.text('Agendar visita'), findsOneWidget);
    await tester.tap(find.text('Agendar visita'));
    await tester.pumpAndSettle();
    expect(find.text('Motivo'), findsOneWidget);
  });

  testWidgets('membro vê contatos da liderança, mas não o rol de membros', (tester) async {
    await pumpApp(tester);
    await entrarComo(tester, 'Membro');
    await aba(tester, 'Pessoas');
    expect(find.text('Contatos'), findsWidgets);
    expect(find.text('Pastores'), findsOneWidget);
    expect(find.text('Diáconos'), findsOneWidget);
    expect(find.text('Sara Lopes'), findsNothing, reason: 'visitante não é contato público');
  });

  testWidgets('coordenação da diaconia gera a escala do mês', (tester) async {
    await pumpApp(tester);
    await entrarComo(tester, 'Diácono · coordena a escala');
    await aba(tester, 'Mais');
    await tester.tap(find.text('Escala diaconal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gerar escala do mês'));
    await tester.pumpAndSettle();
    await rolarAte(tester, 'Gerar prévia');
    await tester.tap(find.text('Gerar prévia'));
    await tester.pumpAndSettle();
    await rolarAte(tester, 'Salvar como rascunho');
    expect(find.textContaining('Publicar'), findsOneWidget);
  });

  testWidgets('evento mostra inscrições, tarefas e orçamento para a liderança', (tester) async {
    await pumpApp(tester, size: const Size(1280, 900));
    await entrarComo(tester, 'Secretaria / administração');
    expect(find.text('PEDRAS VIVAS'), findsOneWidget, reason: 'layout largo com barra lateral');
    await aba(tester, 'Agenda');
    await tester.tap(find.text('Eventos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retiro de casais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orçamento'));
    await tester.pumpAndSettle();
    expect(find.text('SALDO'), findsOneWidget);
    await tester.tap(find.text('Tarefas'));
    await tester.pumpAndSettle();
    expect(find.textContaining('concluídas'), findsOneWidget);
  });

  testWidgets('todas as áreas de Mais abrem', (tester) async {
    await pumpApp(tester);
    await entrarComo(tester, 'Presbítero');
    for (final item in ['Vídeos', 'Avisos', 'Pedidos de oração', 'Meu cadastro']) {
      await aba(tester, 'Mais');
      await tester.ensureVisible(find.text(item));
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: item);
      final back = find.byType(BackButton);
      if (back.evaluate().isNotEmpty) await tester.tap(back.first);
      await tester.pumpAndSettle();
    }
    expect(find.byType(ProviderScope), findsOneWidget);
    expect(isDemoProvider, isNotNull);
  });
}
