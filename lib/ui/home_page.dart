import 'package:flutter/material.dart';

import '../data/agenda_store.dart';
import 'member_page.dart';
import 'pastor_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store});

  final AgendaStore store;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),
                Icon(Icons.church_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 12),
                Text('Agenda Pastoral', style: text.headlineMedium, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Protótipo · escolha como quer entrar',
                  style: text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _EntryCard(
                  key: const Key('entrarComoPastor'),
                  icon: Icons.person_pin_circle_outlined,
                  title: 'Sou o pastor',
                  subtitle: 'Definir dias e horários de visita e ver as reservas',
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => PastorPage(store: store))),
                ),
                const SizedBox(height: 12),
                _EntryCard(
                  key: const Key('entrarComoMembro'),
                  icon: Icons.groups_outlined,
                  title: 'Sou membro',
                  subtitle: 'Ver a agenda do pastor e pedir uma visita',
                  onTap: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => MemberPage(store: store))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
