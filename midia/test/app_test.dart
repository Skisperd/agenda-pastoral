import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:midia_pedras_vivas/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// O relógio de 1 s impede o pumpAndSettle: avançamos o tempo aos poucos.
Future<void> passo(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> abrir(WidgetTester tester, String perfil) async {
  await initializeDateFormatting('pt_BR');
  SharedPreferences.setMockInitialValues({'camera': 'Câmera 2'});
  tester.view
    ..physicalSize = const Size(420, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await tester.runAsync(demoOverrides);
  await tester.pumpWidget(ProviderScope(overrides: overrides!, child: const MidiaApp()));
  await passo(tester);
  await tester.tap(find.text(perfil));
  await passo(tester);
}

Future<void> aba(WidgetTester tester, String nome) async {
  await tester.tap(
    find.descendant(
      of: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_GlassTabBar'),
      matching: find.text(nome),
    ),
  );
  await passo(tester);
}

Future<void> fechar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('liderança vê o que está no ar e comanda o OBS', (tester) async {
    await abrir(tester, 'Liderança de mídia');
    expect(find.text('Ponte ligada'), findsOneWidget);
    expect(find.text('Pregação'), findsWidgets);

    await aba(tester, 'Câmera');
    expect(find.text('NO AR'), findsOneWidget);
    expect(find.text('CÂMERA 2'), findsOneWidget);

    await aba(tester, 'Comandar');
    expect(find.text('TRANSIÇÃO'), findsOneWidget);
    await tester.tap(find.text('TRANSIÇÃO'));
    await passo(tester);
    await passo(tester);

    await aba(tester, 'Câmera');
    // Depois da transição o Louvor (Câmeras 1 e 3) entrou no ar e a 2 foi para a prévia.
    expect(find.text('PRÉVIA'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('operador manda mensagem rápida e não comanda', (tester) async {
    await abrir(tester, 'Operador de câmera');
    await aba(tester, 'Mensagens');
    await tester.tap(find.text('Plano aberto'));
    await passo(tester);
    expect(find.text('Plano aberto'), findsNWidgets(2));

    await aba(tester, 'Comandar');
    expect(find.text('Só a liderança de mídia comanda'), findsOneWidget);
    await fechar(tester);
  });
}
