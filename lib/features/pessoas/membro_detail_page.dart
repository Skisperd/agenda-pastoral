import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/links.dart';
import '../../core/roles.dart';
import '../../core/share.dart';
import '../../core/widgets.dart';
import '../../data/models/pastoral.dart';
import '../../data/models/people.dart';
import '../../data/providers.dart';
import '../common.dart';
import '../pastoral/agendar_sheet.dart';

class MembroDetailPage extends ConsumerWidget {
  const MembroDetailPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(roleProvider);
    final m = ref.watch(memberProvider(id));
    return m.when(
      loading: () => const AppScaffold(title: '', large: false),
      error: (e, _) => const NoAccess(title: 'Cadastro'),
      data: (m) {
        if (m == null) {
          return const AppScaffold(
            title: 'Cadastro',
            large: false,
            slivers: [
              SliverToBoxAdapter(
                child: EmptyState(icon: CupertinoIcons.person, title: 'Cadastro não encontrado'),
              ),
            ],
          );
        }
        return _Body(m: m, role: role);
      },
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.m, required this.role});
  final Membro m;
  final AppRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.pal;
    final today = ref.watch(todayProvider);
    final familia = m.family == null
        ? const <Membro>[]
        : [
            for (final o in ref.watch(membersProvider).value ?? const <Membro>[])
              if (o.family == m.family && o.id != m.id) o,
          ];
    final contas = [
      for (final u in (role.canManageUsers ? ref.watch(usersProvider).value : null) ?? const <AppUser>[])
        if (u.memberId == m.id) u,
    ];
    final visitas = role.isPastoral
        ? [
            for (final v in ref.watch(visitsProvider).value ?? const <Visita>[])
              if (v.memberId == m.id) v,
          ].reversed.toList()
        : const <Visita>[];
    String? d(String? v) => v == null ? null : fmtDate(v);

    return AppScaffold(
      title: m.name,
      large: false,
      previousPageTitle: 'Pessoas',
      maxWidth: kFormWidth,
      actions: [
        if (role.canManageMembers) NavAction(label: 'Editar', onPressed: () => context.go('/pessoas/${m.id}/editar')),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              children: [
                Initials(m.name, size: 84),
                const SizedBox(height: 12),
                Text(m.name, textAlign: TextAlign.center, style: context.text.headlineSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    if (m.oficio != null) OficioPill(m.oficio!),
                    Pill(m.situacao.label, color: m.situacao.isMembro ? pal.green : pal.gray),
                    if (m.selfRegistered) Pill('Cadastro novo', color: pal.orange, icon: CupertinoIcons.sparkles),
                  ],
                ),
                if (m.phone != null || m.email != null) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      if (m.phone != null) ...[
                        TintButton(
                          label: 'WhatsApp',
                          icon: CupertinoIcons.chat_bubble_text_fill,
                          color: pal.green,
                          onPressed: () => openWhatsApp(context, m.phone!),
                        ),
                        TintButton(
                          label: 'Ligar',
                          icon: CupertinoIcons.phone_fill,
                          onPressed: () => callPhone(context, m.phone!),
                        ),
                      ],
                      if (m.email != null)
                        TintButton(
                          label: 'E-mail',
                          icon: CupertinoIcons.mail_solid,
                          color: pal.orange,
                          onPressed: () => sendEmail(context, m.email!),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (m.selfRegistered && role.canManageMembers)
          SliverToBoxAdapter(
            child: NoticeCard(
              icon: CupertinoIcons.checkmark_seal_fill,
              title: 'Conferir cadastro',
              message: 'A própria pessoa se cadastrou como visitante. Ajuste a situação e salve.',
              color: pal.orange,
              onTap: () => context.go('/pessoas/${m.id}/editar'),
            ),
          ),
        SliverToBoxAdapter(
          child: Section(
            header: 'Dados pessoais',
            children: [
              if (m.birthDate != null)
                ListRow(title: 'Nascimento', value: '${d(m.birthDate)} · ${ageOn(m.birthDate, today)} anos'),
              if (m.phone != null) ListRow(title: 'Telefone', value: fmtPhone(m.phone)),
              if (m.email != null) ListRow(title: 'E-mail', subtitle: m.email),
              if (m.maritalStatus != null) ListRow(title: 'Estado civil', value: m.maritalStatus),
              if (m.weddingDate != null) ListRow(title: 'Casamento', value: d(m.weddingDate)),
              if (m.address != null)
                ListRow(
                  title: 'Endereço',
                  subtitle: m.address,
                  trailing: Icon(CupertinoIcons.map_fill, color: pal.accent, size: 20),
                  onTap: () => openUrl(
                    context,
                    Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': m.address}).toString(),
                  ),
                ),
            ],
          ),
        ),
        if (role.canManageMembers)
          SliverToBoxAdapter(
            child: Section(
              header: 'Vida na igreja',
              children: [
                ListRow(title: 'Situação', value: m.situacao.label),
                if (m.admissionMode != null) ListRow(title: 'Admissão', value: m.admissionMode),
                if (m.admissionDate != null) ListRow(title: 'Data da admissão', value: d(m.admissionDate)),
                if (m.baptismDate != null) ListRow(title: 'Batismo', value: d(m.baptismDate)),
                if (m.professionDate != null) ListRow(title: 'Profissão de fé', value: d(m.professionDate)),
                if (m.ministries.isNotEmpty) ListRow(title: 'Ministérios', subtitle: m.ministries.join(', ')),
                if (m.servesDiaconia)
                  ListRow(
                    title: 'Escala diaconal',
                    subtitle: m.funcoes.isEmpty ? 'Todas as funções' : m.funcoes.map((f) => f.label).join(', '),
                  ),
              ],
            ),
          ),
        if (familia.isNotEmpty)
          SliverToBoxAdapter(
            child: Section(
              header: m.family,
              children: [
                for (final f in familia)
                  ListRow(
                    leading: Initials(f.name, size: 32),
                    title: f.name,
                    subtitle: f.situacao.label,
                    onTap: () => context.push('/pessoas/${f.id}'),
                  ),
              ],
            ),
          ),
        if (role.canManageUsers)
          SliverToBoxAdapter(
            child: Section(
              header: 'Acesso ao app',
              footer: contas.isEmpty
                  ? 'Para vincular, abra Mais › Usuários e escolha este cadastro na conta da pessoa.'
                  : null,
              children: [
                for (final u in contas)
                  ListRow(
                    leading: IconTile(u.role.symbol, color: u.role.tint),
                    title: u.email,
                    value: u.role.label,
                  ),
                if (contas.isEmpty) const ListRow(title: 'Sem conta vinculada'),
              ],
            ),
          ),
        if (role.isPastoral) ...[
          SliverToBoxAdapter(child: _NotaPastoral(memberId: m.id)),
          SliverToBoxAdapter(
            child: Section(
              header: 'Visitas pastorais',
              trailing: m.hasLocation
                  ? NavAction(
                      label: 'Marcar',
                      onPressed: () => showAgendarSheet(context, member: m, byPastor: true),
                    )
                  : null,
              footer: m.hasLocation ? null : 'Cadastre o endereço para marcar visitas.',
              children: [
                for (final v in visitas)
                  ListRow(
                    title: '${capitalize(fmtShortDate(v.day))} às ${fmtHour(v.start)}',
                    subtitle: [v.status.label, ?v.reason].join(' · '),
                  ),
                if (visitas.isEmpty) const ListRow(title: 'Nenhuma visita registrada'),
              ],
            ),
          ),
        ],
        if (role.canManageMembers)
          SliverToBoxAdapter(
            child: Section(
              children: [
                ListRow(
                  title: 'Remover cadastro',
                  destructive: true,
                  onTap: () async {
                    if (!await confirm(context, 'Remover ${m.name}?', ok: 'Remover', destructive: true)) return;
                    if (!context.mounted) return;
                    final ok = await guard(
                      context,
                      () => ref.read(repoProvider).deleteMember(m.id),
                      success: 'Removido',
                    );
                    if (ok && context.mounted) context.go('/pessoas');
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Anotações pastorais: só o pastor e a secretaria leem (coleção própria).
class _NotaPastoral extends ConsumerStatefulWidget {
  const _NotaPastoral({required this.memberId});
  final String memberId;

  @override
  ConsumerState<_NotaPastoral> createState() => _NotaPastoralState();
}

class _NotaPastoralState extends ConsumerState<_NotaPastoral> {
  final _ctrl = TextEditingController();
  bool _loaded = false;
  bool _dirty = false;
  String _original = '';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (_loaded && !_dirty && _ctrl.text != _original) setState(() => _dirty = true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final note = ref.watch(_noteProvider(widget.memberId));
    if (!_loaded && note.hasValue) {
      _original = note.value!;
      _ctrl.text = _original;
      _loaded = true;
    }
    return Section(
      header: 'Anotações pastorais',
      footer: 'Reservado: só o pastor e a secretaria veem.',
      trailing: _dirty
          ? NavAction(
              label: 'Salvar',
              bold: true,
              onPressed: () async {
                final ok = await guard(
                  context,
                  () => ref.read(repoProvider).savePastoralNote(widget.memberId, _ctrl.text.trim()),
                  success: 'Anotação salva',
                );
                if (ok && mounted) {
                  setState(() {
                    _dirty = false;
                    _original = _ctrl.text;
                  });
                }
              },
            )
          : null,
      children: [
        FieldRow(
          controller: _ctrl,
          placeholder: 'Acompanhamento, pedidos, situação da família…',
          maxLines: 8,
          minLines: 3,
          capitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }
}

final _noteProvider = StreamProvider.family<String, String>((ref, id) => ref.watch(repoProvider).watchPastoralNote(id));
