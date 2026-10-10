import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_g_kentei/data/progress_store.dart';
import 'package:ukalab_g_kentei/screens/learn_screen.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'test_support.dart';

Question _question() => const Question(
      qid: 'q1',
      examId: 'g_kentei',
      subjectId: 'ml_overview',
      topicId: 'overfitting',
      prompt: '過学習が起こりやすいのはどの場合か。',
      choices: ['データが少ない場合', 'データが多い場合', '正則化が強い場合', '無関係'],
      answerIndex: 0,
      explanation: '過学習は、訓練データに過剰に適合してしまう現象である。',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

// PracticeSession は回答と同時に次の問題へ進む実装のため、1問構成では
// 解説パネルを表示する前に結果画面へ遷移してしまう。内部でシャッフルされ
// どちらが先に出題されるか分からないため、2問目も全く同じ内容にして、
// 出題順に関係なく1問目の回答後に解説を確認できるようにする。
Question _question2() => const Question(
      qid: 'q2',
      examId: 'g_kentei',
      subjectId: 'ml_overview',
      topicId: 'overfitting',
      prompt: '過学習が起こりやすいのはどの場合か。',
      choices: ['データが少ない場合', 'データが多い場合', '正則化が強い場合', '無関係'],
      answerIndex: 0,
      explanation: '過学習は、訓練データに過剰に適合してしまう現象である。',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

// 解説の取り違えを検出するため、内容が互いに異なる2問を使う（以前は同じ内容にして不具合を隠していた）。
Question _qa() => const Question(
      qid: 'qa',
      examId: 'g_kentei',
      subjectId: 'ml_overview',
      topicId: 'a',
      prompt: '問題Aの文',
      choices: ['Aの正解', 'Aの誤り1', 'Aの誤り2', 'Aの誤り3'],
      answerIndex: 0,
      explanation: '解説Aの本文',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

Question _qb() => const Question(
      qid: 'qb',
      examId: 'g_kentei',
      subjectId: 'ml_overview',
      topicId: 'b',
      prompt: '問題Bの文',
      choices: ['Bの正解', 'Bの誤り1', 'Bの誤り2', 'Bの誤り3'],
      answerIndex: 0,
      explanation: '解説Bの本文',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

Widget _learn(List<Question> qs, AdGate adGate, {int? size}) => ProviderScope(
      overrides: [
        handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
        ...studyNotesTestOverrides(),
        coinServiceProvider.overrideWithValue(CoinService(store: InMemoryCoinStore())),
        adGateProvider.overrideWithValue(adGate),
      ],
      child: MaterialApp(
        theme: UkalabTheme.light(field: UkalabField.ai, cert: UkalabCert.gKentei),
        home: Scaffold(
          body: LearnScreen(questions: qs, terms: const [], sessionSize: size ?? qs.length),
        ),
      ),
    );

Term _term() => const Term(
      termId: 't1',
      examId: 'g_kentei',
      subjectId: 'ml_overview',
      term: '過学習',
      headline: '練習問題は得意だが、新しい問題には弱くなること',
      definition: '学習データに対して過剰に適合してしまい、汎化性能が低下する現象。',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('正解すると学習コインが付与される', (tester) async {
    final coinService = CoinService(store: InMemoryCoinStore());
    await coinService.load();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
        ...studyNotesTestOverrides(),
        coinServiceProvider.overrideWithValue(coinService),
        adGateProvider.overrideWithValue(await testAdGate()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: LearnScreen(
            questions: [_question(), _question2()],
            terms: const [],
            sessionSize: 2,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(coinService.balance, 0);
    await tester.tap(find.text('データが少ない場合'));
    await tester.pumpAndSettle();
    expect(coinService.balance, 1);
  });

  testWidgets('連続学習7日目は streak のコインも付与される', (tester) async {
    final coinService = CoinService(store: InMemoryCoinStore());
    await coinService.load();
    var now = DateTime(2026, 10, 1);
    final container = ProviderContainer(overrides: [
        handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
        ...studyNotesTestOverrides(),
      coinServiceProvider.overrideWithValue(coinService),
      progressClockProvider.overrideWithValue(() => now),
      adGateProvider.overrideWithValue(await testAdGate()),
    ]);
    addTearDown(container.dispose);

    await tester.runAsync(() async {
      for (var i = 0; i < 6; i++) {
        await container.read(progressProvider.notifier).recordAnswer('seed-$i', correct: true);
        now = now.add(const Duration(days: 1));
      }
    });
    expect(container.read(progressProvider).streakDays, 6);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: LearnScreen(
            questions: [_question(), _question2()],
            terms: const [],
            sessionSize: 2,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('データが少ない場合'));
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(container.read(progressProvider).streakDays, 7);
    expect(coinService.balance, CoinRules.standard.newQuestion + CoinRules.standard.streak7);
  });

  testWidgets('問題文・解説文中の用語をタップすると用語カードが開く', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
        ...studyNotesTestOverrides(),
        coinServiceProvider.overrideWithValue(CoinService(store: InMemoryCoinStore())),
        adGateProvider.overrideWithValue(await testAdGate()),
      ],
      child: MaterialApp(
        theme: UkalabTheme.light(field: UkalabField.ai, cert: UkalabCert.gKentei),
        home: Scaffold(
          body: LearnScreen(
            questions: [_question(), _question2()],
            terms: [_term()],
            sessionSize: 2,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 問題文中の「過学習」にタップ用の recognizer が付いていること。
    final questionRichText = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((rt) => rt.text.toPlainText().contains('過学習が起こりやすい'));
    final questionOuterSpan = questionRichText.text as TextSpan;
    final questionSpan = questionOuterSpan.children!.single as TextSpan;
    final questionMatched = questionSpan.children!
        .whereType<TextSpan>()
        .where((s) => s.recognizer is TapGestureRecognizer)
        .toList();
    expect(questionMatched.map((s) => s.text), ['過学習']);

    // 選択肢をタップして解説を表示させる。
    await tester.tap(find.text('データが少ない場合'));
    await tester.pumpAndSettle();
    expect(find.text('解説'), findsOneWidget);

    // 解説文中の「過学習」をタップすると用語カードが開く。
    final explanationRichText = tester
        .widgetList<RichText>(find.descendant(
          of: find.byType(ExplanationPanel),
          matching: find.byType(RichText),
        ))
        .firstWhere((rt) => rt.text.toPlainText().contains('過学習は、訓練データに'));
    final explanationOuterSpan = explanationRichText.text as TextSpan;
    final explanationSpan = explanationOuterSpan.children!.single as TextSpan;
    final explanationMatched = explanationSpan.children!
        .whereType<TextSpan>()
        .where((s) => s.recognizer is TapGestureRecognizer)
        .toList();
    expect(explanationMatched.map((s) => s.text), ['過学習']);
    (explanationMatched.single.recognizer as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();
    expect(find.byType(TermCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TermCard),
        matching: find.text('練習問題は得意だが、新しい問題には弱くなること'),
      ),
      findsOneWidget,
    );
  });

  group('回答直後の表示は、回答した問題のものになる（解説が別の問題になる不具合）', () {
    // 出題順はシャッフルされるので、いま出ている問題がAかBかを画面から判定する。
    String shown(WidgetTester tester) =>
        find.text('問題Aの文').evaluate().isNotEmpty ? 'A' : 'B';

    testWidgets('回答直後は、いま出ていた問題の解説が出る（次の問題の解説ではない）', (tester) async {
      await tester.pumpWidget(_learn([_qa(), _qb()], await testAdGate(), size: 2));
      await tester.pumpAndSettle();

      final first = shown(tester);
      final other = first == 'A' ? 'B' : 'A';
      await tester.tap(find.text('$firstの正解'));
      await tester.pumpAndSettle();

      expect(find.text('解説$firstの本文'), findsOneWidget);
      expect(find.text('解説$otherの本文'), findsNothing);
      // 問題文・選択肢も、回答した問題のまま（次の問題に切り替わっていない）。
      expect(find.text('問題$firstの文'), findsOneWidget);
      expect(find.text('問題$otherの文'), findsNothing);
    });

    testWidgets('回答直後の正誤の色は、回答した問題の選択肢に付く', (tester) async {
      await tester.pumpWidget(_learn([_qa(), _qb()], await testAdGate(), size: 2));
      await tester.pumpAndSettle();

      final first = shown(tester);
      await tester.tap(find.text('$firstの誤り1'));
      await tester.pumpAndSettle();

      // 回答した問題の選択肢が全て残っていて、次の問題の選択肢は出ていない。
      expect(find.text('$firstの正解'), findsOneWidget);
      expect(find.text('$firstの誤り1'), findsOneWidget);
      final other = first == 'A' ? 'B' : 'A';
      expect(find.text('$otherの正解'), findsNothing);
    });

    testWidgets('「次へ」で次の問題に進み、解説は消える', (tester) async {
      await tester.pumpWidget(_learn([_qa(), _qb()], await testAdGate(), size: 2));
      await tester.pumpAndSettle();

      final first = shown(tester);
      final other = first == 'A' ? 'B' : 'A';
      await tester.tap(find.text('$firstの正解'));
      await tester.pumpAndSettle();
      // 解説の下にメモ欄が入って縦に長くなったので、ボタンを画面内へ寄せてから押す。
      await tester.ensureVisible(find.text('次へ'));
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      expect(find.text('問題$otherの文'), findsOneWidget);
      expect(find.text('解説$firstの本文'), findsNothing);
      expect(find.text('解説'), findsNothing);
    });

    testWidgets('最後の問題でも、解説を見てから「次へ」で結果画面に進む', (tester) async {
      await tester.pumpWidget(_learn([_qa()], await testAdGate(), size: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aの正解'));
      await tester.pumpAndSettle();
      // 以前は、回答した瞬間に結果画面へ飛び、最後の解説が読めなかった。
      expect(find.text('解説Aの本文'), findsOneWidget);
      expect(find.byType(ResultSummary), findsNothing);

      // 解説の下にメモ欄が入って縦に長くなったので、ボタンを画面内へ寄せてから押す。
      await tester.ensureVisible(find.text('次へ'));
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();
      expect(find.byType(ResultSummary), findsOneWidget);
    });

    testWidgets('回答後に選択肢を押し直しても、記録は変わらない（二重回答しない）', (tester) async {
      await tester.pumpWidget(_learn([_qa(), _qb()], await testAdGate(), size: 2));
      await tester.pumpAndSettle();

      final first = shown(tester);
      await tester.tap(find.text('$firstの正解'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('$firstの誤り1'));
      await tester.pumpAndSettle();

      expect(find.text('解説$firstの本文'), findsOneWidget);
      expect(find.byType(ResultSummary), findsNothing);
    });
  });
}
