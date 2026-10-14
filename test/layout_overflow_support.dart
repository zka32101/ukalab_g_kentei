import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 文字切れ・はみ出し検査の共通部品（レイアウト例外を集めて、原因が自アプリか共有パッケージかを分ける）。

class LayoutHit {
  LayoutHit(this.message, this.loc, {required this.shared});
  final String message;
  final String loc;
  final bool shared;
  @override
  String toString() => '$message @ $loc';
}

String _shortLoc(String l) {
  final m = RegExp(r'/lib/(.*)$').firstMatch(l);
  final pkg = RegExp(r'/(ukalab_core|app_common_kit)-').firstMatch(l)?.group(1);
  return '${pkg ?? 'app'}:${m?.group(1) ?? l}';
}

/// レイアウト例外を集める。
class LayoutCollector {
  final hits = <LayoutHit>[];
  void Function(FlutterErrorDetails)? _prev;

  void start() {
    _prev = FlutterError.onError;
    FlutterError.onError = (d) {
      final first = d.exceptionAsString().split('\n').first;
      // 先に起きた例外の巻き添え（レイアウトされていない描画物など）は数えない。
      if (hits.isNotEmpty &&
          (first.contains('was not laid out') || first.contains('Failed assertion'))) {
        return;
      }
      final dump = d.toDiagnosticsNode().toStringDeep(minLevel: DiagnosticLevel.hidden);
      final locs = RegExp(r'file:///\S+?\.dart:\d+:\d+')
          .allMatches(dump)
          .map((m) => m.group(0)!)
          .where((l) =>
              !l.contains('/packages/flutter/') &&
              !l.contains('/flutter_test/') &&
              !l.contains('/test/'))
          .map(_shortLoc)
          .toList();
      // Flutter 標準の日付ピッカー（showDatePicker）自体のはみ出しは、アプリでは直せない。
      final framework = dump.contains('_DatePickerHeader') || dump.contains('DatePickerDialog');
      final loc = framework ? 'flutter:DatePickerDialog' : (locs.isEmpty ? '?' : locs.first);
      hits.add(LayoutHit(first, loc, shared: !loc.startsWith('app:') && loc != '?'));
    };
  }

  void stop() => FlutterError.onError = _prev;
}
