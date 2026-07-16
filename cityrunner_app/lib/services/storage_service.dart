import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import 'firebase_bootstrap.dart';

class StorageService {
  StorageService._();

  static final instance = StorageService._();

  Future<String> uploadImage({
    required String path,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    if (!FirebaseBootstrap.isReady) throw StateError('Firebase Storage is not configured.');
    final compressed = await FlutterImageCompress.compressWithList(bytes, quality: 82, minWidth: 1440, minHeight: 1440);
    final reference = FirebaseStorage.instance.ref(path);
    await reference.putData(compressed, SettableMetadata(contentType: contentType));
    return reference.getDownloadURL();
  }

  Future<String> uploadDocument({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (!FirebaseBootstrap.isReady) throw StateError('Firebase Storage is not configured.');
    final reference = FirebaseStorage.instance.ref(path);
    await reference.putData(bytes, SettableMetadata(contentType: contentType));
    return reference.getDownloadURL();
  }
}
