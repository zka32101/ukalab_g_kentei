import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_g_kentei/data/oshi_growth.dart';
import 'package:ukalab_g_kentei/data/progress_store.dart';
import 'package:ukalab_g_kentei/main.dart';
import 'package:ukalab_g_kentei/widgets/core_v069_home_cards.dart' show OshiGrowthSection;

import 'test_support.dart';

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
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(app);
    await Future.delayed(const Duration(milliseconds: 300));
  });
  await tester.pumpAndSettle();
}

ProgressRecord _rec(int i, {bool correct = true, String subject = 's1'}) => ProgressRecord(
      qid: 'q$i',
      subjectId: subject,
      correct: correct,
      at: DateTime(2026, 10, 1 + i % 3, 9),
    );

void main() {
  testWidgets('ホームに今日の復習が出て、成長の吹き出しは出ない(履歴なしでは分析は出ない)', (tester) async {
    await _boot(tester);
    expect(find.byType(TodayReviewCard), findsOneWidget);
    expect(find.byType(OshiGrowthSection), findsOneWidget); // 祝福の見張り役は残す
    expect(find.byType(OshiGrowthBubble, skipOffstage: false), findsNothing);
    expect(find.byType(MockExamAnalysisCard), findsNothing);
    // 既存の入口は残っている。
    expect(find.text('間違いノート'), findsOneWidget);
    expect(find.text('収録問題数'), findsOneWidget);
  });

  testWidgets('履歴があると模擬試験の結果分析が出て、分野名は科目名で表示される', (tester) async {
    await _boot(tester, prefs: {
      'ukalab_g_kentei_history_v1':
          encodeHistory([for (var i = 0; i < 4; i++) _rec(i, correct: i.isEven)]),
    });
    expect(find.byType(MockExamAnalysisCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('間違いノートに期限の問題があると今日の復習に件数が出る', (tester) async {
    await _boot(tester, prefs: {
      'ukalab_g_kentei_history_v1': encodeHistory([
        ProgressRecord(
          qid: 'will-be-filtered',
          subjectId: 's1',
          correct: false,
          at: DateTime(2020, 1, 1),
        ),
      ]),
    });
    // 出題データに無い問題は数えない → おやすみ表示(0件)。
    final card = tester.widget<TodayReviewCard>(find.byType(TodayReviewCard));
    expect(card.dueCount, 0);
  });

  testWidgets('節目(10問)に届いていると祝福が一度だけ出る', (tester) async {
    await _boot(tester, prefs: {
      'ukalab_g_kentei_history_v1': encodeHistory([for (var i = 0; i < 12; i++) _rec(i)]),
    });
    expect(find.byType(OshiGrowthCelebrationCard), findsOneWidget);
    final done = await tester.runAsync(oshiGrowthStore.read);
    expect(done, contains('answered_10'));
  });

  test('累計は履歴の件数と解いた種類数の大きい方、学習日数は履歴の日数', () {
    final p = oshiGrowthProgressFor(
      records: [_rec(1), _rec(2), _rec(3)],
      progress: const ProgressState(
        answeredQidToCorrect: {'a': true, 'b': true, 'c': true, 'd': true, 'e': false},
        streakDays: 1,
      ),
    );
    expect(p.totalAnswered, 5);
    expect(p.studyDays, 3);
  });

  for (final lang in ['ja']) {
    testWidgets('幅320・文字2倍でもオーバーフローしない($lang)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearAllTestValues();
      });
      await _boot(tester, prefs: {
        'ukalab_g_kentei_history_v1':
            encodeHistory([for (var i = 0; i < 6; i++) _rec(i, correct: i.isEven)]),
      });
      expect(find.byType(TodayReviewCard), findsOneWidget);
      expect(find.byType(OshiGrowthBubble, skipOffstage: false), findsNothing);
      expect(find.byType(MockExamAnalysisCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
