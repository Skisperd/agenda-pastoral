export 'embed_view_io.dart' if (dart.library.js_interop) 'embed_view_web.dart';

/// Como exibir um vídeo dentro do app.
class EmbedSource {
  const EmbedSource({required this.url, required this.youtubeId, this.start, this.autoplay = false});

  final String url;

  /// Vídeos do YouTube no celular são montados via HTML próprio (evita o erro 153).
  final String youtubeId;
  final int? start;

  /// Começa a tocar sozinho.
  final bool autoplay;
}

/// Player do YouTube para um link (youtu.be, watch?v=, shorts, live), ou `null`.
EmbedSource? embedForUrl(String raw, {bool autoplay = false}) {
  final u = Uri.tryParse(raw.trim());
  if (u == null || !u.hasScheme) return null;
  final host = u.host.toLowerCase();
  String? yt;
  if (host.endsWith('youtu.be')) yt = u.pathSegments.firstOrNull;
  if (host.contains('youtube.com')) {
    yt =
        u.queryParameters['v'] ??
        (u.pathSegments.length >= 2 && {'embed', 'shorts', 'live'}.contains(u.pathSegments.first)
            ? u.pathSegments[1]
            : null);
  }
  if (yt == null || yt.isEmpty) return null;
  final start = int.tryParse((u.queryParameters['start'] ?? u.queryParameters['t'] ?? '').replaceAll('s', ''));
  final q = {'rel': '0', 'playsinline': '1', 'modestbranding': '1', 'start': ?start?.toString()};
  return EmbedSource(
    url: Uri.https('www.youtube.com', '/embed/$yt', q).toString(),
    youtubeId: yt,
    start: start,
    autoplay: autoplay,
  );
}

/// HTML do player do YouTube para WebView (origem própria, exigida pelo YouTube).
/// Usa a IFrame API para avisar o app quando o vídeo termina (canal "Igreja"
/// no app; `postMessage` para a página no navegador), o que permite tocar o
/// repertório em sequência, cada vídeo a partir do minuto da música.
String youtubeHtml(String id, int? start, [int? end, bool autoplay = false]) =>
    '''
<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;height:100%;background:#000}#p{width:100%;height:100%}</style></head>
<body><div id="p"></div>
<script src="https://www.youtube.com/iframe_api"></script>
<script>
function tell(m){ if (window.Igreja) { Igreja.postMessage(m); } else if (window.parent !== window) { parent.postMessage({igreja: m}, '*'); } }
function onYouTubeIframeAPIReady(){
  new YT.Player('p', {
    videoId: '$id',
    playerVars: {playsinline: 1, rel: 0, modestbranding: 1, autoplay: ${autoplay ? 1 : 0}${start == null ? '' : ', start: $start'}${end == null ? '' : ', end: $end'}},
    events: {
      onReady: function(e){ ${autoplay ? 'e.target.playVideo();' : ''} tell('ready'); },
      onStateChange: function(e){ if (e.data === 0) tell('ended'); },
      onError: function(e){ tell('error:' + e.data); }
    }
  });
}
</script></body></html>''';
