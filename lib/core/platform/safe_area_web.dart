import 'package:web/web.dart' as web;

/// Site aberto pela Tela de Início do iPhone: o Flutter web não recebe a área segura
/// (indicador de início, notch), então medimos por CSS os elementos-sonda do index.html,
/// cujo tamanho é env(safe-area-inset-*). Se a medição falhar num iPhone sem botão
/// físico em modo app, assume os 34 px do indicador.
double _probe(String id) {
  final el = web.document.getElementById(id);
  if (el == null) return 0;
  final h = el.getBoundingClientRect().height;
  return h.isFinite && h > 0 ? h.toDouble() : 0;
}

bool get _standalone => web.window.matchMedia('(display-mode: standalone)').matches;
bool get _iPhone => RegExp(r'iPhone').hasMatch(web.window.navigator.userAgent);

/// iPhones com Face ID têm tela com proporção acima de 2:1.
bool get _semBotao {
  final s = web.window.screen;
  final w = s.width, h = s.height;
  return w > 0 && (h > w ? h / w : w / h) > 2.0;
}

double webSafeAreaBottom() {
  final medido = _probe('safe-bottom');
  if (medido > 0) return medido;
  return _standalone && _iPhone && _semBotao ? 34 : 0;
}

double webSafeAreaTop() => _probe('safe-top');

/// Texto de diagnóstico para a página de Ajuda.
String webSafeAreaDebug() =>
    'Área segura medida: topo ${_probe('safe-top').round()} px, base ${_probe('safe-bottom').round()} px · '
    'modo app: ${_standalone ? 'sim' : 'não'} · iPhone: ${_iPhone ? 'sim' : 'não'} · '
    'tela ${web.window.screen.width}×${web.window.screen.height} · '
    'viewport ${web.window.innerWidth}×${web.window.innerHeight}';
