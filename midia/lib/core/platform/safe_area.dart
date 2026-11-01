import 'package:flutter/widgets.dart';

import 'safe_area_io.dart' if (dart.library.js_interop) 'safe_area_web.dart';

export 'safe_area_io.dart' if (dart.library.js_interop) 'safe_area_web.dart' show webSafeAreaDebug;

/// Garante a área segura no site instalado na Tela de Início do iPhone, onde o
/// Flutter web informa zero: completa o MediaQuery com o que o CSS mede.
class WebSafeArea extends StatelessWidget {
  const WebSafeArea({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottom = webSafeAreaBottom();
    final top = webSafeAreaTop();
    if (bottom <= mq.padding.bottom && top <= mq.padding.top) return child;
    final padding = mq.padding.copyWith(
      bottom: bottom > mq.padding.bottom ? bottom : mq.padding.bottom,
      top: top > mq.padding.top ? top : mq.padding.top,
    );
    return MediaQuery(
      data: mq.copyWith(
        padding: padding,
        viewPadding: mq.viewPadding.copyWith(
          bottom: bottom > mq.viewPadding.bottom ? bottom : mq.viewPadding.bottom,
          top: top > mq.viewPadding.top ? top : mq.viewPadding.top,
        ),
      ),
      child: child,
    );
  }
}
