import 'dart:js_interop';

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'embed.dart';

/// Web: o conteúdo é exibido num `<iframe>` dentro da página. Para o YouTube,
/// `enablejsapi` faz o player mandar o estado por `postMessage`, e assim a
/// sequência do culto avança quando o vídeo termina.
class EmbedView extends StatefulWidget {
  const EmbedView(this.source, {super.key, this.onEnded});
  final EmbedSource source;
  final VoidCallback? onEnded;

  @override
  State<EmbedView> createState() => _EmbedViewState();
}

class _EmbedViewState extends State<EmbedView> {
  web.HTMLIFrameElement? _frame;
  JSFunction? _listener;

  @override
  void initState() {
    super.initState();
    _listener = ((web.MessageEvent e) {
      final f = _frame;
      if (f == null || e.source != f.contentWindow) return;
      final data = e.data;
      if (data == null || !data.typeofEquals('string')) return;
      final text = (data as JSString).toDart;
      // {"event":"onStateChange","info":0} = terminou
      if (text.contains('"onStateChange"') && RegExp(r'"info"\s*:\s*0[,}]').hasMatch(text)) widget.onEnded?.call();
    }).toJS;
    web.window.addEventListener('message', _listener);
  }

  @override
  void dispose() {
    if (_listener != null) web.window.removeEventListener('message', _listener);
    super.dispose();
  }

  String get _src {
    final s = widget.source;
    final u = Uri.parse(s.url);
    return u
        .replace(
          queryParameters: {
            ...u.queryParameters,
            'enablejsapi': '1',
            'origin': web.window.location.origin,
            if (s.autoplay) 'autoplay': '1',
          },
        )
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    return HtmlElementView.fromTagName(
      key: ValueKey('${source.url}${source.autoplay}'),
      tagName: 'iframe',
      onElementCreated: (element) {
        final f = element as web.HTMLIFrameElement;
        _frame = f;
        f.src = _src;
        f.onLoad.listen((_) {
          // Pede ao player para mandar os eventos de estado.
          f.contentWindow?.postMessage('{"event":"listening","id":1,"channel":"widget"}'.toJS, '*'.toJS);
        });
        f
          ..allow = 'autoplay; encrypted-media; picture-in-picture; fullscreen'
          ..allowFullscreen = true
          ..referrerPolicy = 'strict-origin-when-cross-origin';
        f.style
          ..border = '0'
          ..width = '100%'
          ..height = '100%'
          ..backgroundColor = 'transparent';
      },
    );
  }
}
