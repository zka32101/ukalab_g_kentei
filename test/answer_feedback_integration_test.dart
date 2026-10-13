import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/answer_feedback.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_g_kentei/data/history_store.dart';
import 'package:ukalab_g_kentei/screens/learn_screen.dart';
import 'package:ukalab_g_kentei/screens/premium_practice_cards.dart';

import 'test_support.dart';

Question _q(String qid) => Question(
      qid: qid,
      examId: 'g_kentei',
      subjectId: 'ml_overview',
      topicId: 'ch1',
      prompt: '問題$qidの文',
      choices: const ['正解の選択肢', '誤りの選択肢'],
      answerIndex: 0,
      explanation: '解説$qid',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

Future<ProviderContainer> _pumpLearn(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
    ...studyNotesTestOverrides(),
    coinServiceProvider.overrideWithValue(CoinService(store: InMemoryCoinStore())),
    adGateProvider.overrideWithValue(await testAdGate()),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: LearnScreen(questions: [_q('a'), _q('b')], terms: const [], sessionSize: 2),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tapAndSettle(WidgetTester tester, String text) async {
  await tester.runAsync(() async {
    await tester.tap(find.text(text));
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pumpCards(WidgetTester tester, {required bool premium}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
    ...studyNotesTestOverrides(),
    adGateProvider.overrideWithValue(await testAdGate()),
    entitlementStateProvider.overrideWith(
      (ref) => Stream.value(EntitlementState(hasPremium: premium)),
    ),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: PremiumPracticeCards(
          exam: ExamConfig(
            examId: 'g_kentei',
            name: 'G検定',
            audience: Audience.adult,
            subjects: const [],
            levels: const [],
          ),
          questions: [_q('a')],
          terms: const [],
          clock: () => DateTime(2026, 11, 20, 12),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  testWidgets('不正解だと原因パネルが出て、原因を選ぶと履歴に付く', (tester) async {
    final c = await _pumpLearn(tester);
    expect(find.byType(AnswerFeedbackPanel), findsOneWidget); // 回答前は枠だけ（中身は空）
    expect(find.text('知識不足'), findsNothing);

    await _tapAndSettle(tester, '誤りの選択肢');
    expect(find.text('知識不足'), findsOneWidget);
    expect(c.read(historyProvider).single.cause, isNull);

    await tester.runAsync(() async {
      await tester.tap(find.text('知識不足'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    final rec = c.read(historyProvider).single;
    expect(rec.correct, isFalse);
    expect(rec.cause, WrongCause.knowledge);
    // G検定は計算問題が無いので「計算ミス」は選べない。
    expect(find.text('計算ミス'), findsNothing);
  });

  testWidgets('正解では原因パネルの中身は出ない', (tester) async {
    final c = await _pumpLearn(tester);
    await _tapAndSettle(tester, '正解の選択肢');
    expect(find.text('知識不足'), findsNothing);
    expect(c.read(historyProvider).single.correct, isTrue);
  });

  testWidgets('premiumなら今週の弱点カードを出す', (tester) async {
    await _pumpCards(tester, premium: true);
    expect(find.byType(WeakSummaryCard), findsOneWidget);
  });

  testWidgets('premiumでなければ今週の弱点カードを出さない', (tester) async {
    await _pumpCards(tester, premium: false);
    expect(find.byType(WeakSummaryCard), findsNothing);
  });
}
