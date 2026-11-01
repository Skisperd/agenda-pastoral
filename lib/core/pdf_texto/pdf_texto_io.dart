import 'dart:typed_data';

/// Celular: a leitura do PDF é feita pelo site.
Future<String> pdfParaTexto(Uint8List bytes) =>
    Future.error(UnsupportedError('Para importar perguntas de um PDF, use o app pelo navegador.'));
