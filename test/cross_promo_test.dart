import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/cross_promo.dart';
import 'package:ukalab_g_kentei/screens/settings_screen.dart' show kCrossPromoAppId;

void main() {
  test('相互紹介の自アプリIDは、うかラボの正規ID一覧に含まれる', () {
    expect(isUkalabAppId(kCrossPromoAppId), isTrue);
  });

  testWidgets('掲載リストが空（Firebase無しのテスト環境）なら、何も表示せず例外にもならない', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: UkalabCrossPromoSection(currentAppId: kCrossPromoAppId)),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('他のアプリもチェック！'), findsNothing);
  });
}
