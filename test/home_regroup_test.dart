import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_g_kentei/main.dart';
import 'package:ukalab_g_kentei/screens/mistake_note_screen.dart';

import 'test_support.dart';

const _keyPrefix = 'ukalab_g_kentei_home_section_';

const _labTitles = [
  'AIと法律の境界線',
  '予測→実行',
  '推しの答案を添削',
  '学習の失敗図鑑',
  '評価指標ラボ',
  '手法の選び方',
  '機械学習ラボ',
  '画像認識の中身を見る',
  'Transformerの注意の可視化',
  'ニューラルネット組み立て',
  'AI倫理ケース',
  'AIプロジェクト経営モード',
];

Future<Widget> _app() async {
  final gate = await testAdGate();
  return ProviderScope(
    overrides: [
      handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
      ...studyNotesTestOverrides(),
      coinServiceProvider.overrideWithValue(CoinService(store: InMemoryCoinStore())),
      outfitServiceProvider.overrideWithValue(OutfitService(store: InMemoryOutfitStore())),
      entitlementServiceProvider.overrideWithValue(FakeEntitlementService()),
      adGateProvider.overrideWithValue(gate),
      examStatsServiceProvider.overrideWithValue(FakeExamStatsService()),
    ],
    child: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: const UkalabGKenteiApp(),
    ),
  );
}

Future<void> _boot(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  await tester.runAsync(() async {
    final app = await _app();
    // testAdGate が保存値を空に初期化するので、その後に差し込む。
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(app);
    await Future.delayed(const Duration(milliseconds: 300));
  });
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('各グループの見出しが表示される', (tester) async {
    await _boot(tester);
    for (final h in ['今日やること', '記録', '試験に向けて', '道具', '体験ラボ']) {
      expect(find.text(h), findsOneWidget, reason: h);
    }
    expect(find.byType(HomeSectionHeader), findsNWidgets(5));
  });

  testWidgets('体験ラボは初期は畳まれ、道具などは展開されている', (tester) async {
    await _boot(tester);
    expect(find.text('AIと法律の境界線'), findsNothing);
    expect(find.text('用語集'), findsOneWidget);
    expect(find.text('最短ルートプランナー'), findsOneWidget);
    expect(find.text('収録問題数'), findsOneWidget);
  });

  testWidgets('既存の入口がすべて残っている（体験ラボを開いて確認）', (tester) async {
    await _boot(tester);
    for (final t in [
      'ながらセッション',
      '最短ルートプランナー',
      '145問ペース走',
      '間違いノート',
      '収録問題数',
      '用語集',
      '用語マップ・AI系譜図',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await _tapText(tester, '体験ラボ');
    for (final t in _labTitles) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('代表的な入口をタップすると遷移できる', (tester) async {
    await _boot(tester);

    await _tapText(tester, '間違いノート');
    expect(find.byType(MistakeNoteScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _tapText(tester, 'ながらセッション');
    expect(find.text('全体から'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _tapText(tester, '145問ペース走');
    expect(find.text('ペース走を始める'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _tapText(tester, '用語集');
    expect(find.text('用語を検索'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _tapText(tester, '体験ラボ');
    await _tapText(tester, '評価指標ラボ');
    expect(find.text('がん検診'), findsOneWidget);
  });

  testWidgets('条件付き表示: データが無いAI動向は出さない', (tester) async {
    await _boot(tester);
    expect(find.byType(AiNewsCard), findsNothing);
    expect(find.text('今月のAI動向'), findsNothing);
  });

  testWidgets('折りたたみの開閉が保存され、保存値が復元される', (tester) async {
    await _boot(tester);

    // 体験ラボを開く → true が保存される。
    await _tapText(tester, '体験ラボ');
    expect(find.text('AIと法律の境界線'), findsOneWidget);
    var prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getBool('${_keyPrefix}lab'), isTrue);

    // 道具を畳む → false が保存され、用語集が隠れる。
    await _tapText(tester, '道具');
    expect(find.text('用語集'), findsNothing);
    prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getBool('${_keyPrefix}tools'), isFalse);

    // もう一度開く。
    await _tapText(tester, '道具');
    expect(find.text('用語集'), findsOneWidget);
  });

  testWidgets('保存された開閉状態で起動する', (tester) async {
    await _boot(tester, prefs: {
      '${_keyPrefix}lab': true,
      '${_keyPrefix}tools': false,
    });
    expect(find.text('AIと法律の境界線'), findsOneWidget);
    expect(find.text('用語集'), findsNothing);
    // 畳んでいても見出しは残り、開けば入口に届く。
    await _tapText(tester, '道具');
    expect(find.text('用語集'), findsOneWidget);
    expect(find.text('用語マップ・AI系譜図'), findsOneWidget);
  });

  testWidgets('狭い幅と大きい文字でもオーバーフローしない', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearAllTestValues();
    });
    await _boot(tester, prefs: {'${_keyPrefix}lab': true});
    expect(find.text('AIと法律の境界線'), findsOneWidget);
    // 1 列にフォールバックしている。
    expect(find.byKey(const ValueKey('home-grid-1')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _tapText(tester, '道具');
    await _tapText(tester, '道具');
    expect(tester.takeException(), isNull);
  });
}
