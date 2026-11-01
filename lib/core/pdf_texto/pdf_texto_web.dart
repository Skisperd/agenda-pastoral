import 'dart:js_interop';
import 'dart:typed_data';

@JS('pdfTexto')
external JSPromise<JSString> _pdfTexto(JSUint8Array bytes);

/// Texto do PDF, linha a linha (pdf.js, em web/pdf_texto.js).
Future<String> pdfParaTexto(Uint8List bytes) async => (await _pdfTexto(bytes.toJS).toDart).toDart;
