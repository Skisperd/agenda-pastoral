import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'embed.dart';

/// Android/iOS: o conteúdo é exibido numa WebView dentro do app.
class EmbedView extends StatefulWidget {
  const EmbedView(this.source, {super.key, this.onEnded});
  final EmbedSource source;

  /// Chamado quando um vídeo do YouTube chega ao fim (para tocar o próximo).
  final VoidCallback? onEnded;

  @override
  State<EmbedView> createState() => _EmbedViewState();
}

class _EmbedViewState extends State<EmbedView> {
  late WebViewController _controller = _create();

  WebViewController _create() {
    final params = defaultTargetPlatform == TargetPlatform.iOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    final c = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000));
    if (c.platform is AndroidWebViewController) {
      (c.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }
    final s = widget.source;
    c.addJavaScriptChannel(
      'Igreja',
      onMessageReceived: (m) {
        if (m.message == 'ended') widget.onEnded?.call();
      },
    );
    c.loadHtmlString(
      youtubeHtml(s.youtubeId, s.start, null, s.autoplay),
      baseUrl: 'https://agenda-pastoral-15bff.web.app',
    );
    return c;
  }

  @override
  void didUpdateWidget(EmbedView old) {
    super.didUpdateWidget(old);
    if (old.source.url != widget.source.url) setState(() => _controller = _create());
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(key: ValueKey(widget.source.url), controller: _controller);
}
