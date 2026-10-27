import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Converte links de embed (como vêm do Notion) em links abríveis.
String normalizeUrl(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null) return url;
  // youtube.com/embed/ID?start=N  ->  youtube.com/watch?v=ID&t=N
  if (u.host.contains('youtube.com') && u.pathSegments.length >= 2 && u.pathSegments.first == 'embed') {
    final start = u.queryParameters['start'];
    return Uri.https('www.youtube.com', '/watch', {'v': u.pathSegments[1], 't': ?start}).toString();
  }
  // drive.google.com/file/d/ID/preview  ->  /view
  if (u.host == 'drive.google.com' && u.pathSegments.length >= 4 && u.pathSegments.last == 'preview') {
    return Uri.https(u.host, [...u.pathSegments.take(u.pathSegments.length - 1), 'view'].join('/')).toString();
  }
  return url.trim();
}

/// Identificador do vídeo, quando o link for do YouTube.
String? youtubeVideoId(String url) {
  final u = Uri.tryParse(normalizeUrl(url));
  if (u == null) return null;
  String? id;
  if (u.host.contains('youtu.be')) id = u.pathSegments.firstOrNull;
  if (u.host.contains('youtube.com')) {
    id = u.queryParameters['v'];
    // youtube.com/shorts/ID, youtube.com/live/ID
    if (id == null && u.pathSegments.length >= 2 && const {'shorts', 'live', 'embed'}.contains(u.pathSegments.first)) {
      id = u.pathSegments[1];
    }
  }
  return (id == null || id.isEmpty) ? null : id;
}

/// Link do YouTube começando no segundo [start] (para abrir fora do app no mesmo trecho).
String withStart(String url, int? start) {
  final id = start == null ? null : youtubeVideoId(url);
  if (id == null) return normalizeUrl(url);
  return Uri.https('www.youtube.com', '/watch', {'v': id, 't': '${start}s'}).toString();
}

/// Miniatura do YouTube, quando o link for de vídeo.
String? youtubeThumb(String url) {
  final id = youtubeVideoId(url);
  return id == null ? null : 'https://img.youtube.com/vi/$id/mqdefault.jpg';
}

/// Playlist temporária do YouTube com os vídeos, na ordem dada.
/// Abre no app/site do YouTube como uma fila: não precisa de conta nem de criar playlist.
String? youtubeQueueUrl(Iterable<String> videoUrls) {
  final ids = videoUrls.map(youtubeVideoId).nonNulls.toSet().toList();
  if (ids.isEmpty) return null;
  return 'https://www.youtube.com/watch_videos?video_ids=${ids.join(',')}';
}

IconData iconForUrl(String url) {
  final u = url.toLowerCase();
  if (u.contains('youtu')) return Icons.smart_display;
  if (u.contains('docs.google.com/presentation')) return Icons.slideshow;
  if (u.contains('drive.google') || u.endsWith('.pdf')) return Icons.picture_as_pdf;
  if (u.contains('spotify') || u.contains('soundcloud')) return Icons.headphones;
  if (u.contains('cifraclub')) return Icons.queue_music;
  return Icons.link;
}

Future<void> openUrl(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(normalizeUrl(url)), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível abrir $url')));
  }
}

bool isValidUrl(String? v) {
  if (v == null || v.trim().isEmpty) return true;
  final u = Uri.tryParse(v.trim());
  return u != null && (u.scheme == 'http' || u.scheme == 'https') && u.host.isNotEmpty;
}
