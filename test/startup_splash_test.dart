import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_g_kentei/main.dart';

void main() {
  testWidgets('StartupSplash にアプリアイコンとブランド色が渡る', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: StartupSplash(
        appIconAsset: kStartupIconAsset,
        backgroundColor: kStartupBackground,
        appIconSize: 160,
      ),
    ));
    final splash = tester.widget<StartupSplash>(find.byType(StartupSplash));
    expect(splash.appIconAsset, 'assets/icon/app_icon_foreground.png');
    expect(splash.backgroundColor, const Color(0xFF6D4AD8));
    final icon = tester
        .widgetList<Image>(find.byType(Image))
        .where((i) => i.image is AssetImage && (i.image as AssetImage).assetName == kStartupIconAsset);
    expect(icon.length, 1);
    expect(icon.first.width, 160);
  });

  test('起動アイコンのアセットが実在し pubspec に宣言されている', () {
    expect(kStartupIconAsset, 'assets/icon/app_icon_foreground.png');
  });
}
