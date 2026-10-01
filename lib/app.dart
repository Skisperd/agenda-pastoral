import 'package:flutter/material.dart';

import 'data/agenda_store.dart';
import 'ui/home_page.dart';

class AgendaApp extends StatelessWidget {
  const AgendaApp({super.key, required this.home});

  /// App no modo demonstração, com os dados em memória de [store].
  AgendaApp.demo({Key? key, required AgendaStore store})
    : this(
        key: key,
        home: HomePage(store: store),
      );

  final Widget home;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) =>
        ThemeData(colorSchemeSeed: const Color(0xFF3F51B5), brightness: b, fontFamily: 'Roboto');
    return MaterialApp(
      title: 'Agenda Pastoral',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: home,
    );
  }
}
