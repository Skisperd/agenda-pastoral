import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Armazenamento de arquivos (PDFs, áudios…) enviados pela liderança.
abstract class FileStore {
  bool get available;

  /// Envia [bytes] para [path] e devolve a URL de download.
  Future<String> upload(String path, Uint8List bytes, {String? contentType, void Function(double)? onProgress});
}

class FirebaseFileStore implements FileStore {
  FirebaseFileStore(this._storage);
  final FirebaseStorage _storage;

  @override
  bool get available => true;

  @override
  Future<String> upload(String path, Uint8List bytes, {String? contentType, void Function(double)? onProgress}) async {
    final ref = _storage.ref(path);
    final task = ref.putData(bytes, SettableMetadata(contentType: contentType, cacheControl: 'public, max-age=86400'));
    final sub = task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress?.call(s.bytesTransferred / s.totalBytes);
    });
    try {
      await task;
    } finally {
      await sub.cancel();
    }
    return ref.getDownloadURL();
  }
}

/// Modo demonstração: não há onde guardar arquivos.
class UnavailableFileStore implements FileStore {
  @override
  bool get available => false;

  @override
  Future<String> upload(String path, Uint8List bytes, {String? contentType, void Function(double)? onProgress}) =>
      throw UnsupportedError('Envio de arquivos indisponível no modo demonstração.');
}

/// Tipo MIME pela extensão do arquivo.
String? contentTypeFor(String name) => switch (name.split('.').last.toLowerCase()) {
  'pdf' => 'application/pdf',
  'mp3' => 'audio/mpeg',
  'm4a' => 'audio/mp4',
  'aac' => 'audio/aac',
  'wav' => 'audio/wav',
  'ogg' || 'opus' => 'audio/ogg',
  'mp4' || 'm4v' => 'video/mp4',
  'mov' => 'video/quicktime',
  'webm' => 'video/webm',
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'mscz' => 'application/octet-stream',
  _ => null,
};
