import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart';

import 'download_png_stub.dart' if (dart.library.js_interop) 'download_png_web.dart' as dl;

const _shareText = '#うかラボ #G検定';
const _fileName = 'ukalab_g_kentei.png';

/// 画像（共有カード）をOSの共有シートで共有する。保存も共有シート経由（専用のギャラリー保存は持たない）。
///
/// Web で共有に対応していない（Web Share API が無い／ファイル共有不可）ブラウザでは、
/// 共有が例外になるので、PNG のダウンロードへフォールバックする。share_plus 自身のダウンロード
/// フォールバックは切り、ここで一本化する（成功時は結果が `unavailable` になるため、結果では判定しない）。
/// [share]・[download]・[isWeb] はテスト用の差し替え口。
Future<void> shareCardImage(
  Uint8List png, {
  Future<ShareResult> Function(ShareParams params)? share,
  void Function(Uint8List png, String fileName)? download,
  bool? isWeb,
}) async {
  final web = isWeb ?? kIsWeb;
  final doShare = share ?? SharePlus.instance.share;
  final doDownload = download ?? dl.downloadPng;
  try {
    await doShare(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png', name: _fileName)],
        text: _shareText,
        downloadFallbackEnabled: false,
      ),
    );
  } catch (_) {
    if (!web) rethrow;
    doDownload(png, _fileName);
  }
}
