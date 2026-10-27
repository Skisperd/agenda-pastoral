import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/embed/embed.dart';
import '../core/format.dart';
import '../core/links.dart';
import '../core/roles.dart';
import '../core/share.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import '../data/models/conteudo.dart';
import '../data/models/igreja.dart';
import '../data/models/people.dart';
import '../data/providers.dart';

/// Cor e ícone de cada tipo de atividade.
extension CategoriaStyle on Categoria {
  IconData get icon => switch (this) {
    Categoria.culto => CupertinoIcons.book_fill,
    Categoria.ebd => CupertinoIcons.book_circle_fill,
    Categoria.oracao => CupertinoIcons.heart_circle_fill,
    Categoria.estudo => CupertinoIcons.book,
    Categoria.ensaio => CupertinoIcons.music_mic,
    Categoria.sociedade => CupertinoIcons.person_3_fill,
    Categoria.reuniao => CupertinoIcons.chat_bubble_2_fill,
    Categoria.conferencia => CupertinoIcons.speaker_3_fill,
    Categoria.retiro => CupertinoIcons.tree,
    Categoria.social => CupertinoIcons.heart_fill,
    Categoria.missao => CupertinoIcons.globe,
    Categoria.outro => CupertinoIcons.star_fill,
  };

  Color color(Palette p) => switch (this) {
    Categoria.culto => Brand.navy,
    Categoria.ebd => Brand.blue,
    Categoria.oracao => p.purple,
    Categoria.estudo => p.indigo,
    Categoria.ensaio => p.pink,
    Categoria.sociedade => p.teal,
    Categoria.reuniao => p.gray,
    Categoria.conferencia => p.orange,
    Categoria.retiro => p.green,
    Categoria.social => p.red,
    Categoria.missao => const Color(0xFFA2845E),
    Categoria.outro => p.yellow,
  };
}

/// Atividade da semana: horário à esquerda, título e local.
class AgendaRow extends StatelessWidget {
  const AgendaRow(this.item, {super.key, this.showDay = false});
  final ItemAgenda item;
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final c = item.categoria ?? Categoria.outro;
    return ListRow(
      leading: SizedBox(
        width: 50,
        child: Column(
          children: [
            if (showDay) Text(weekdayShort[item.start.weekday - 1].toUpperCase(), style: trackedLabel(c.color(pal))),
            Text(
              fmtHour(item.start),
              style: TextStyle(fontFamily: numFont, fontSize: 15, fontWeight: FontWeight.w700, color: pal.label),
            ),
          ],
        ),
      ),
      title: item.title,
      subtitle: [
        if (item.end != null) 'até ${fmtHour(item.end!)}',
        ?item.place,
        if (item.eventId != null) 'Evento',
      ].join(' · '),
      trailing: Icon(c.icon, size: 18, color: c.color(pal)),
      chevron: item.eventId != null,
      onTap: item.eventId == null ? null : () => context.push('/agenda/evento/${item.eventId}'),
    );
  }
}

/// Cartão de vídeo com miniatura (abre o player).
class VideoCard extends StatelessWidget {
  const VideoCard(this.video, {super.key, this.width = 260});
  final Video video;
  final double width;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Tappable(
      onTap: () => showVideo(context, video),
      pressedOpacity: .7,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(decoration: const BoxDecoration(gradient: Brand.heroGradient)),
                    if (video.thumb != null)
                      Image.network(
                        video.thumb!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    Center(
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .55), shape: BoxShape.circle),
                        child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 22),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Pill(video.tipo.label, color: Colors.black.withValues(alpha: .6), solid: true),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
            const SizedBox(height: 2),
            Text(
              [capitalize(fmtShortDate(video.date)), ?video.speaker, ?video.bibleText].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(color: pal.secondaryLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Player do YouTube numa folha, com botão para abrir no app do YouTube.
Future<void> showVideo(BuildContext context, Video v) {
  final embed = embedForUrl(v.url, autoplay: true);
  return showSheet<void>(
    context,
    builder: (c) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(title: v.tipo.label, cancel: 'Fechar'),
          if (embed != null)
            AspectRatio(aspectRatio: 16 / 9, child: EmbedView(embed))
          else
            const EmptyState(icon: CupertinoIcons.play_rectangle, title: 'Link sem vídeo do YouTube'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(v.title, style: c.text.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              [capitalize(fmtLongDate(v.date)), ?v.speaker, ?v.bibleText].join(' · '),
              style: c.text.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TintButton(
              label: 'Abrir no YouTube',
              icon: CupertinoIcons.play_rectangle_fill,
              large: true,
              expand: true,
              color: const Color(0xFFFF0000),
              onPressed: () => openUrl(c, v.url),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Pessoa com ações de contato (WhatsApp, ligar, e-mail).
class ContactRow extends StatelessWidget {
  const ContactRow(this.m, {super.key, this.onTap});
  final Membro m;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    Widget action(IconData i, Color c, VoidCallback f, String tip) => Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tip,
        child: Tappable(
          onTap: f,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: c.withValues(alpha: .12), shape: BoxShape.circle),
            child: Icon(i, size: 17, color: c),
          ),
        ),
      ),
    );
    return ListRow(
      leading: Initials(m.name),
      title: m.name,
      subtitle: [?m.oficio?.label, if (m.phone != null) fmtPhone(m.phone)].join(' · '),
      onTap: onTap,
      chevron: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (m.phone != null) ...[
            action(CupertinoIcons.chat_bubble_text_fill, pal.green, () => openWhatsApp(context, m.phone!), 'WhatsApp'),
            action(CupertinoIcons.phone_fill, pal.accent, () => callPhone(context, m.phone!), 'Ligar'),
          ],
          if (m.email != null)
            action(CupertinoIcons.mail_solid, pal.orange, () => sendEmail(context, m.email!), 'E-mail'),
        ],
      ),
    );
  }
}

/// Página bloqueada para o perfil atual.
class NoAccess extends StatelessWidget {
  const NoAccess({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: title,
    large: false,
    slivers: const [
      SliverToBoxAdapter(
        child: EmptyState(
          icon: CupertinoIcons.lock,
          title: 'Sem permissão',
          message: 'Peça à secretaria para ajustar o seu perfil.',
        ),
      ),
    ],
  );
}

/// Rótulo do ofício/situação como selo.
class OficioPill extends StatelessWidget {
  const OficioPill(this.oficio, {super.key});
  final Oficio oficio;

  @override
  Widget build(BuildContext context) => Pill(oficio.label, color: oficio.tint, icon: oficio.icon);
}
