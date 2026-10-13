import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// PNG をブラウザのダウンロードとして保存する（共有に対応していないブラウザ向け）。
void downloadPng(Uint8List png, String fileName) {
  final blob = web.Blob([png.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName;
  a.click();
  web.URL.revokeObjectURL(url);
}
