import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ui.dart'
    show FileSaver, PremiumBenefitsCard, PremiumBenefitsStrings;
import 'package:ukalab_core/ukalab_core.dart' show Question, QuestionSource;
import 'package:ukalab_g_kentei/data/history_store.dart';
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

Question _question(String qid) => Question(
      qid: qid,
      examId: 'g',
      subjectId: 's1',
      topicId: 'ch1',
      prompt: 'p',
      explanation: 'e',
      source: QuestionSource.original,
      sourceRef: 'r',
      contentVer: '1',
      choices: const ['a', 'b'],
      answerIndex: 0,
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

  testWidgets('無料の間はプレミアムでできることのカードが出る（購入節の中・価格なし）', (tester) async {
    _tall(tester);
    await tester.pumpWidget(_app(_service()));
    await tester.pumpAndSettle();

    expect(find.byType(PremiumBenefitsCard), findsOneWidget);
    expect(find.text('プレミアムでできること'), findsOneWidget);
    expect(find.text(PremiumBenefitsStrings.ja.benefits.values.first.name), findsOneWidget);
    expect(find.byKey(const ValueKey('premiumFreeNote')), findsOneWidget);
    // 「公式」「合格保証」は使わない（設定の非公式の注記には出るので、カードの範囲に限る）。
    final card = find.byType(PremiumBenefitsCard);
    expect(find.descendant(of: card, matching: find.textContaining('合格保証')), findsNothing);
    expect(find.descendant(of: card, matching: find.textContaining('公式')), findsNothing);
  });

  testWidgets('広告非表示だけの購入者にはカードが残り、プレミアム購入者には出ない', (tester) async {
    final service = _service();
    _tall(tester);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('¥480'));
    await tester.pumpAndSettle();
    expect(find.text('広告非表示を購入済みです'), findsOneWidget);
    expect(find.byType(PremiumBenefitsCard), findsOneWidget);

    service.restorable = const EntitlementState(hasPremium: true);
    await tester.tap(find.text('購入を復元'));
    await tester.pumpAndSettle();
    expect(find.text('プレミアムを購入済みです'), findsOneWidget);
    expect(find.byType(PremiumBenefitsCard), findsNothing);
  });

  group('学習履歴のCSV', () {
    Future<ProviderContainer> seeded(WidgetTester tester, {required bool withRecord}) async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer(overrides: [
        entitlementServiceProvider.overrideWithValue(_service()),
        handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
        ...studyNotesTestOverrides(),
      ]);
      addTearDown(container.dispose);
      if (withRecord) {
        // 実際の非同期処理（SharedPreferences）なので、FakeAsync の外で待つ。
        await tester.runAsync(() => container
            .read(historyProvider.notifier)
            .record(_question('q1'), correct: true, at: DateTime(2026, 10, 20, 9)));
      }
      return container;
    }

    Widget host(ProviderContainer container, FileSaver saver) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SettingsScreen(fileSaver: saver, now: () => DateTime(2026, 10, 21)),
            ),
          ),
        );

    testWidgets('タップするとファイル保存（UTF-8 BOM・text/csv・日付入りの名前）を呼び、クリップボードは使わない', (tester) async {
      final calls = <({Uint8List bytes, String fileName, String mimeType})>[];
      final container = await seeded(tester, withRecord: true);
      _tall(tester);
      await tester.pumpWidget(host(container, ({
        required Uint8List bytes,
        required String fileName,
        required String mimeType,
        Rect? sharePositionOrigin,
      }) async {
        calls.add((bytes: bytes, fileName: fileName, mimeType: mimeType));
        return true;
      }));
      await tester.pumpAndSettle();

      expect(find.text('学習履歴をコピー（CSV）'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('downloadHistoryCsv')));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single.fileName, 'ukalab_history_20261021.csv');
      expect(calls.single.mimeType, 'text/csv');
      expect(calls.single.bytes.take(3), [0xEF, 0xBB, 0xBF]);
      final text = utf8.decode(calls.single.bytes.skip(3).toList());
      expect(text, startsWith('日付,解答数,正答数,正答率(%),学習時間(分)'));
      expect(text, contains('2026-10-20,1,1,100.0'));
      expect(text, isNot(contains('q1')));
      expect(find.text('書き出しました'), findsOneWidget);
    });

    testWidgets('履歴が空ならファイルを作らず、その旨を表示する', (tester) async {
      var called = false;
      final container = await seeded(tester, withRecord: false);
      _tall(tester);
      await tester.pumpWidget(host(container, ({
        required Uint8List bytes,
        required String fileName,
        required String mimeType,
        Rect? sharePositionOrigin,
      }) async {
        called = true;
        return true;
      }));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('downloadHistoryCsv')));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.text('まだ学習履歴がありません。'), findsOneWidget);
    });

    testWidgets('保存に失敗したら失敗の文言を表示する', (tester) async {
      final container = await seeded(tester, withRecord: true);
      _tall(tester);
      await tester.pumpWidget(host(container, ({
        required Uint8List bytes,
        required String fileName,
        required String mimeType,
        Rect? sharePositionOrigin,
      }) async =>
          throw Exception('x')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('downloadHistoryCsv')));
      await tester.pumpAndSettle();

      expect(find.text('書き出せませんでした'), findsOneWidget);
    });
  });
}
