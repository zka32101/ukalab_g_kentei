import 'dart:math';

import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_g_kentei/data/exam_repository.dart';
import 'package:ukalab_g_kentei/data/feature_flags.dart';
import 'package:ukalab_g_kentei/data/history_store.dart';
import 'package:ukalab_g_kentei/data/progress_store.dart';
import 'package:ukalab_g_kentei/screens/learn_screen.dart';
import 'package:ukalab_g_kentei/screens/nagara_entry.dart';

import 'test_support.dart';

// 新タイプの問題はテスト内の最小フィクスチャ（出荷する assets には入れない）。

Question _base(String id, QuestionType type,
        {String prompt = '', bool? answerBool, List<ClozeBlank> blanks = const [], String? clue,
        List<String> answers = const [], List<String> choices = const []}) =>
    Question(
      qid: id,
      examId: 'g_kentei',
      subjectId: 'ml_overview',
      topicId: 't',
      type: type,
      prompt: prompt,
      explanation: '$idの解説文',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
      answerBool: answerBool,
      blanks: blanks,
      clue: clue,
      answers: answers,
      choices: choices,
    );

Question _choice(String id) => Question(
      qid: id,
      examId: 'g_kentei',
      subjectId: 'ml_overview',
      topicId: 't',
      prompt: '選択式$id',
      choices: ['$idの正解', '$idの誤り1', '$idの誤り2', '$idの誤り3'],
      answerIndex: 0,
      explanation: '$idの解説',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

Question _tf() => _base('tf1', QuestionType.trueFalse, prompt: '過学習は訓練データへ過剰に適合する現象である。', answerBool: true);

Question _cloze() => _base('cz1', QuestionType.cloze,
    prompt: '{{1}}は訓練データに適合しすぎる現象である。', blanks: const [ClozeBlank(id: 1, answers: ['過学習'])]);

Question _rev() => _base('rv1', QuestionType.reverseLookup,
    prompt: '次の説明に当てはまる用語は何か。',
    clue: '訓練データに過剰に適合し汎化性能が下がる現象',
    answers: const ['過学習'],
    choices: const ['過学習', '正則化', '汎化', '転移学習']);

List<Question> _mixed() => [_choice('c1'), _tf(), _cloze(), _rev()];

ExamData _examData(List<Question> qs, {bool? enabled}) {
  final e = enabled;
  return ExamData(
    exam: const ExamConfig(
        examId: 'g_kentei', name: 'G検定', audience: Audience.adult, subjects: [], levels: [], examDates: []),
    questions: qs,
    terms: const [],
    boundaryScenarios: const [],
    predictRunScenarios: const [],
    misconceptionScenarios: const [],
    failureCases: const [],
    confusionMatrixScenarios: const [],
    methodChoiceScenarios: const [],
    mlLabDatasets: const [],
    aiNewsItems: const [],
    convLabImages: const [],
    attentionVizScenarios: const [],
    nnBuilderDatasets: const [],
    ethicsCaseScenarios: const [],
    storyScenarios: const [],
    chapterReadings: const [],
    newQuestionTypesEnabled: e ?? kNewQuestionTypesEnabled,
  );
}

Widget _app(List<Question> qs, AdGate gate,
        {bool newTypesEnabled = true, int? size, List<Override> extra = const []}) =>
    ProviderScope(
      overrides: [
        handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
        ...studyNotesTestOverrides(),
        coinServiceProvider.overrideWithValue(CoinService(store: InMemoryCoinStore())),
        adGateProvider.overrideWithValue(gate),
        ...extra,
      ],
      child: MaterialApp(
        theme: UkalabTheme.light(field: UkalabField.ai, cert: UkalabCert.gKentei),
        home: Scaffold(
          body: LearnScreen(
            questions: qs,
            terms: const [],
            sessionSize: size ?? qs.length,
            newTypesEnabled: newTypesEnabled,
          ),
        ),
      ),
    );

ProviderContainer _container(WidgetTester t) => ProviderScope.containerOf(t.element(find.byType(LearnScreen)));

void main() {
  _displayPromptTests();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // 解答後は結果・解説・間違えた理由・「次へ」が縦に並ぶので、縦長の画面で試す。
  void tall(WidgetTester t) {
    t.view.physicalSize = const Size(800, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  group('フラグ（既定 OFF）', () {
    test('既定は OFF で、模擬試験の許可タイプは core 既定の4タイプ', () {
      expect(kNewQuestionTypesEnabled, isFalse);
      expect(kMockExamAllowedTypes, defaultMockExamTypes);
      expect(kMockExamAllowedTypes.contains(QuestionType.trueFalse), isFalse);
    });

    test('OFF: 新タイプは出題プールから除かれ、選択式はそのまま（順序も同じ）', () {
      final out = selectableQuestions(_mixed(), newTypesEnabled: false);
      expect(out.map((q) => q.qid), ['c1']);
      expect(identical(out.first, _mixed().first), isFalse); // 新リスト
      expect(selectableQuestions([_choice('a'), _choice('b')], newTypesEnabled: false).map((q) => q.qid), ['a', 'b']);
    });

    test('ON: 新タイプも含む', () {
      expect(selectableQuestions(_mixed(), newTypesEnabled: true).map((q) => q.qid), ['c1', 'tf1', 'cz1', 'rv1']);
    });

    test('ExamData.activeQuestions: 既定（OFF）では新タイプが混ざっていても出ない / ON で出る / disabled は常に除く', () {
      final qs = [..._mixed(), _choice('off').copyWithDisabledForTest()];
      expect(_examData(qs).activeQuestions.map((q) => q.qid), ['c1']);
      expect(_examData(qs, enabled: false).activeQuestions.map((q) => q.qid), ['c1']);
      expect(_examData(qs, enabled: true).activeQuestions.map((q) => q.qid), ['c1', 'tf1', 'cz1', 'rv1']);
    });

    test('模擬試験: フラグ ON 相当でもプールに新タイプがあっても、既定の許可タイプでは出ない', () {
      final level = LevelConfig(
          levelId: 'l', name: 'l', questionCount: 10, timeLimitSec: 600, passRule: const PassRule(totalPct: 70));
      final picked = pickMockExamQuestions(pool: _mixed(), level: level, allowedTypes: kMockExamAllowedTypes);
      expect(picked.map((q) => q.qid), ['c1']);
      final custom = pickCustomMockExamQuestions(
          pool: _mixed(), subjectIds: const ['ml_overview'], count: 10, allowedTypes: kMockExamAllowedTypes);
      expect(custom.map((q) => q.qid), ['c1']);
    });

    test('ながらセッション: フラグに関わらず新タイプを除く（全出題元）', () {
      final hist = <ProgressRecord>[];
      for (final src in NagaraSource.values) {
        final pool = buildNagaraPool(src,
            questions: _mixed(),
            history: hist,
            mistakeQids: {'c1', 'tf1', 'cz1', 'rv1'},
            random: Random(1));
        expect(pool.map((q) => q.qid).toSet().difference({'c1'}), isEmpty, reason: '$src');
      }
      expect(toNagaraQuestions(_mixed()).map((n) => n.id), ['c1']);
    });

    testWidgets('OFF: 演習に新タイプだけを渡しても出ない（空表示）', (tester) async {
      await tester.pumpWidget(_app([_tf(), _cloze(), _rev()], await testAdGate(), newTypesEnabled: false));
      await tester.pumpAndSettle();
      expect(find.text('問題データがまだありません。'), findsOneWidget);
    });

    testWidgets('OFF: 選択式との混在でも選択式だけが出て、従来どおり解答できる', (tester) async {
      await tester.pumpWidget(_app(_mixed(), await testAdGate(), newTypesEnabled: false, size: 10));
      await tester.pumpAndSettle();
      expect(find.text('選択式c1'), findsOneWidget);
      expect(find.byType(TrueFalseQuestionView), findsNothing);
      await tester.tap(find.text('c1の正解'));
      await tester.pumpAndSettle();
      expect(_container(tester).read(progressProvider).answeredQidToCorrect, {'c1': true});
    });
  });

  group('履歴の自己申告補正', () {
    test('直近の不正解を正解に直し、原因を外す。正解済み・無い qid は変えない', () {
      final at = DateTime(2026, 10, 1);
      final recs = [
        ProgressRecord(qid: 'a', subjectId: 's', correct: false, at: at, cause: WrongCause.misread),
        ProgressRecord(qid: 'b', subjectId: 's', correct: false, at: at),
      ];
      final out = markLatestRecordCorrect(recs, 'a');
      expect(out[0].correct, isTrue);
      expect(out[0].cause, isNull);
      expect(out[1].correct, isFalse);
      expect(markLatestRecordCorrect(out, 'a'), same(out));
      expect(markLatestRecordCorrect(recs, 'zzz'), same(recs));
    });
  });

  group('演習（フラグ ON）', () {
    testWidgets('○×: 解答が PracticeSession・履歴・進捗に反映され、間違いは履歴に不正解で残る', (tester) async {
      tall(tester);
      await tester.pumpWidget(_app([_tf()], await testAdGate()));
      await tester.pumpAndSettle();
      expect(find.byType(TrueFalseQuestionView), findsOneWidget);

      await tester.tap(find.textContaining('誤り').first); // × を選ぶ（正解は○）
      await tester.pumpAndSettle();
      final c = _container(tester);
      expect(c.read(progressProvider).answeredQidToCorrect, {'tf1': false});
      final h = c.read(historyProvider);
      expect(h.length, 1);
      expect(h.single.qid, 'tf1');
      expect(h.single.correct, isFalse);
      expect(find.textContaining('不正解'), findsWidgets);
      expect(find.text('tf1の解説文'), findsOneWidget);
      // 間違いノートは履歴から作られる
      expect(const MistakeNoteEngine().update(const [], h).map((e) => e.qid), ['tf1']);

      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();
      expect(find.byType(TrueFalseQuestionView), findsNothing); // 結果画面へ
    });

    testWidgets('○×: 正解は正解として記録される', (tester) async {
      tall(tester);
      await tester.pumpWidget(_app([_tf()], await testAdGate()));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('正しい').first);
      await tester.pumpAndSettle();
      final c = _container(tester);
      expect(c.read(progressProvider).answeredQidToCorrect, {'tf1': true});
      expect(c.read(historyProvider).single.correct, isTrue);
    });

    testWidgets('空欄補充（自由入力）: 誤答 → 自己申告で履歴・進捗が正解に直る', (tester) async {
      tall(tester);
      await tester.pumpWidget(_app([_cloze()], await testAdGate()));
      await tester.pumpAndSettle();
      expect(find.byType(ClozeQuestionView), findsOneWidget);

      await tester.enterText(find.byType(TextField), '過学習み');
      await tester.pump();
      await tester.tap(find.text('解答する'));
      await tester.pumpAndSettle();
      final c = _container(tester);
      expect(c.read(historyProvider).single.correct, isFalse);
      expect(c.read(progressProvider).answeredQidToCorrect, {'cz1': false});

      await tester.tap(find.text('合っていた（自己申告）'));
      await tester.pumpAndSettle();
      expect(c.read(historyProvider).single.correct, isTrue);
      expect(c.read(progressProvider).answeredQidToCorrect, {'cz1': true});
      expect(c.read(historyProvider).length, 1);
    });

    testWidgets('空欄補充: 正解入力は正解として記録される', (tester) async {
      tall(tester);
      await tester.pumpWidget(_app([_cloze()], await testAdGate()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '過学習');
      await tester.pump();
      await tester.tap(find.text('解答する'));
      await tester.pumpAndSettle();
      expect(_container(tester).read(historyProvider).single.correct, isTrue);
    });

    testWidgets('説明から用語（選択肢つき）: 選ぶと採点され記録される', (tester) async {
      tall(tester);
      await tester.pumpWidget(_app([_rev()], await testAdGate()));
      await tester.pumpAndSettle();
      expect(find.byType(ReverseLookupQuestionView), findsOneWidget);
      await tester.tap(find.text('正則化'));
      await tester.pumpAndSettle();
      final c = _container(tester);
      expect(c.read(progressProvider).answeredQidToCorrect, {'rv1': false});
      expect(c.read(historyProvider).single.qid, 'rv1');
      expect(c.read(historyProvider).single.correct, isFalse);
    });

    testWidgets('選択式と新タイプの混在でも、全問を通して解答できる（選択式の挙動は従来どおり）', (tester) async {
      tall(tester);
      await tester.pumpWidget(_app([_choice('c1'), _tf()], await testAdGate(), size: 2));
      await tester.pumpAndSettle();
      final c = _container(tester);
      for (var i = 0; i < 2; i++) {
        if (find.byType(TrueFalseQuestionView).evaluate().isNotEmpty) {
          await tester.tap(find.textContaining('正しい').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('次へ'));
        } else {
          await tester.tap(find.text('c1の正解'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('次へ'));
        }
        await tester.pumpAndSettle();
      }
      expect(c.read(progressProvider).answeredQidToCorrect, {'c1': true, 'tf1': true});
      expect(c.read(historyProvider).length, 2);
    });
  });
}

extension on Question {
  Question copyWithDisabledForTest() => Question(
        qid: qid,
        examId: examId,
        subjectId: subjectId,
        topicId: topicId,
        prompt: prompt,
        choices: choices,
        answerIndex: answerIndex,
        explanation: explanation,
        source: source,
        sourceRef: sourceRef,
        contentVer: contentVer,
        disabled: true,
      );
}

void _displayPromptTests() {
  test('一覧用の問題文 displayPrompt: 4択は prompt と同じ（従来どおり）', () {
    final q = _choice('c1');
    expect(q.displayPrompt, q.prompt);
  });
}
