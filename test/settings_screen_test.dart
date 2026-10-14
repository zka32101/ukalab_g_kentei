import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ukalab_g_kentei/screens/settings_screen.dart';

import 'test_support.dart';

const _noAdsOffer = EntitlementOffer(
  id: 'noads',
  productId: 'g_kentei_noads',
  title: '広告非表示',
  priceString: '¥480',
);
const _premiumOffer = EntitlementOffer(
  id: 'premium',
  productId: 'g_kentei_premium',
  title: 'プレミアム（広告非表示＋追加機能）',
  priceString: '¥1,500',
);

FakeEntitlementService _service() => FakeEntitlementService(
      availableOffers: const [_noAdsOffer, _premiumOffer],
      grantOnPurchase: const {
        'g_kentei_noads': EntitlementState(hasNoAds: true),
        'g_kentei_premium': EntitlementState(hasPremium: true),
      },
    );

Widget _app(FakeEntitlementService service) => ProviderScope(
      overrides: [
        entitlementServiceProvider.overrideWithValue(service),
        handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
        ...studyNotesTestOverrides(),
      ],
      child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
    );

/// 設定画面は長い ListView。既定の小さな画面だと下の項目が組み立てられないので、縦長にする。
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('バージョンは固定文字でなく、実際の版を表示する', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'test',
      packageName: 'com.example.test',
      version: '9.8.7',
      buildNumber: '42',
      buildSignature: '',
    );
    _tall(tester);
    await tester.pumpWidget(_app(_service()));
    await tester.pumpAndSettle();

    expect(find.text('9.8.7'), findsOneWidget);
    expect(find.text('0.1.0'), findsNothing);
  });

  testWidgets('無料の間は購入ボタンが出る', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(_service()));
    await tester.pumpAndSettle();

    expect(find.text('広告非表示'), findsOneWidget);
    expect(find.text('¥480'), findsOneWidget);
    expect(find.text('プレミアム（広告非表示＋追加機能）'), findsOneWidget);
  });

  testWidgets('購入すると購入済み表示になり、ボタンが消える', (tester) async {
    final service = _service();
    _tall(tester);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('¥480'));
    await tester.pumpAndSettle();

    expect(find.text('広告非表示を購入済みです'), findsOneWidget);
    expect(find.text('広告非表示'), findsNothing);
    expect(service.state.hasNoAds, isTrue);
  });

  testWidgets('復元できる購入がなければその旨を表示する', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(_service()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('購入を復元'));
    await tester.pumpAndSettle();

    expect(find.text('復元できる購入がありませんでした。'), findsOneWidget);
  });

  testWidgets('復元できる購入があれば購入済み表示になる', (tester) async {
    final service = _service()..restorable = const EntitlementState(hasPremium: true);
    _tall(tester);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('購入を復元'));
    await tester.pumpAndSettle();

    expect(find.text('購入を復元しました。'), findsOneWidget);
    expect(find.text('プレミアムを購入済みです'), findsOneWidget);
  });

  testWidgets('設定画面の相互紹介は、掲載リストが空（Firebase無し）なら何も出ず例外にもならない', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(_service()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('他のアプリもチェック！'), findsNothing);
  });
}
