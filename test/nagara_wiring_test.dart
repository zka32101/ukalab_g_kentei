import 'dart:math';

import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:app_common_kit/hands_free_tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_g_kentei/data/history_store.dart';
import 'package:ukalab_g_kentei/data/mistake_notes.dart';
import 'package:ukalab_g_kentei/data/progress_store.dart';
import 'package:ukalab_g_kentei/screens/nagara_entry.dart';
import 'package:ukalab_g_kentei/screens/settings_screen.dart';

import 'test_support.dart';

Question _q(String id, {String subject = 'ml_overview'}) => Question(
      qid: id,
      examId: 'g_kentei',
      subjectId: subject,
      topicId: 't',
      prompt: '問題$idの文',
      choices: ['$idの正解', '$idの誤り1', '$idの誤り2', '$idの誤り3'],
      answerIndex: 0,
      explanation: '$idの解説',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

ExamConfig _exam() => const ExamConfig(
      examId: 'g_kentei',
      name: 'G検定',
      audience: Audience.adult,
      subjects: [],
      levels: [],
      examDates: [],
    );

class _Env {
  _Env(this.speech, this.store, this.container);
  final FakeSpeechBackend speech;
  final InMemoryHandsFreeStore store;
  final ProviderContainer container;
}

Future<_Env> _env(WidgetTester tester, Widget home) async {
  SharedPreferences.setMockInitialValues({});
  final speech = FakeSpeechBackend();
  final store = InMemoryHandsFreeStore();
  final coin = CoinService(store: InMemoryCoinStore());
  await coin.load();
  final container = ProviderContainer(overrides: [
    speechBackendProvider.overrideWithValue(speech),
    entitlementServiceProvider.overrideWithValue(FakeEntitlementService()),
    handsFreeStoreProvider.overrideWithValue(store),
    coinServiceProvider.overrideWithValue(coin),
    adGateProvider.overrideWithValue(await testAdGate()),
    ...studyNotesTestOverrides(),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: Scaffold(body: home)),
  ));
  await tester.pump();
  return _Env(speech, store, container);
}

Future<void> _openSession(WidgetTester tester) async {
  await tester.tap(find.text('ながらセッション'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('全体から'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('入口から開いて、ながらセッションが始まり、停止で止まる', (tester) async {
    final env = await _env(
        tester, NagaraEntryCard(exam: _exam(), questions: [_q('a'), _q('b')], terms: const []));
    await _openSession(tester);

    expect(find.byType(NagaraSessionView), findsOneWidget);
    expect(env.speech.spoken, hasLength(1));
    expect(env.speech.spoken.single, contains('の文'));

    await tester.tap(find.text('終了'));
    await tester.pump();
    expect(find.text('おつかれさまでした'), findsOneWidget);
    final spokenAtStop = env.speech.spoken.length;
    expect(env.speech.stopCount, greaterThan(0));

    // 停止後は時間が経っても何も読まない。
    await tester.pump(const Duration(seconds: 30));
    expect(env.speech.spoken.length, spokenAtStop);
  });

  testWidgets('誤答は1回だけ履歴に載り、間違いノートにも取り込まれる', (tester) async {
    final env = await _env(tester,
        NagaraSessionScreen(questions: [_q('a')], maxQuestions: 5));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.text('aの誤り1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final history = env.container.read(historyProvider);
    expect(history.map((r) => r.qid), ['a']);
    expect(history.single.correct, isFalse);
    expect(env.container.read(progressProvider).distinctAnswered, 1);
    final notes = mistakeNoteEngine.build(history);
    expect(notes.map((e) => e.qid), ['a']);
    expect(find.text('おつかれさまでした'), findsOneWidget);
  });

  testWidgets('正解のタップも履歴・進捗に1回だけ載り、間違いノートの克服が進む', (tester) async {
    final env = await _env(tester, const SizedBox());
    final history = env.container.read(historyProvider.notifier);
    final q = _q('a');
    await history.record(q, correct: false, at: DateTime(2026, 10, 1));
    await history.record(q, correct: true, at: DateTime(2026, 10, 2));
    expect(mistakeNoteEngine.build(env.container.read(historyProvider)).single.overcome, isFalse);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: env.container,
      child: MaterialApp(home: NagaraSessionScreen(questions: [q], maxQuestions: 5)),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('aの正解'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final records = env.container.read(historyProvider);
    expect(records, hasLength(3));
    expect(records.last.correct, isTrue);
    expect(env.container.read(progressProvider).distinctAnswered, 1);
    expect(mistakeNoteEngine.build(records).single.overcome, isTrue);
  });

  testWidgets('スキップは履歴・進捗に載らない', (tester) async {
    final env = await _env(tester,
        NagaraSessionScreen(questions: [_q('a'), _q('b')], maxQuestions: 5));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('スキップ'));
    await tester.pump();
    await tester.tap(find.text('終了'));
    await tester.pump();
    expect(env.container.read(historyProvider), isEmpty);
    expect(env.container.read(progressProvider).distinctAnswered, 0);
  });

  testWidgets('考える間を過ぎて未回答でも責めず、履歴には載せない。設定の秒数が反映される', (tester) async {
    final env = await _env(tester, const SizedBox());
    await env.container.read(handsFreeProvider.notifier).setThinkSeconds(3);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: env.container,
      child: MaterialApp(
        home: NagaraSessionScreen(questions: [_q('a'), _q('b')], maxQuestions: 5),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));

    await tester.pump(const Duration(seconds: 2));
    expect(env.speech.spoken, hasLength(1)); // まだ考える間
    await tester.pump(const Duration(seconds: 2));
    expect(env.speech.spoken, hasLength(2)); // 答えと解説を読んだ
    expect(env.speech.spoken.last, contains('解説'));
    expect(env.container.read(historyProvider), isEmpty);

    await tester.tap(find.text('終了'));
    await tester.pump();
  });

  testWidgets('上限問数に達したら、責めずに休憩をすすめて終わる', (tester) async {
    await _env(tester,
        NagaraSessionScreen(questions: [_q('a'), _q('b'), _q('c')], maxQuestions: 1));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('aの誤り2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('おつかれさまでした'), findsOneWidget);
    expect(find.textContaining('ひと休み'), findsOneWidget);
    expect(find.text('とじる'), findsOneWidget);
  });

  test('出題元ごとの問題の選び方', () {
    final qs = [_q('a'), _q('b', subject: 'other'), _q('c')];
    final history = [
      ProgressRecord(qid: 'b', subjectId: 'other', correct: true, at: DateTime(2026, 10, 12)),
      ProgressRecord(qid: 'a', subjectId: 'ml_overview', correct: false, at: DateTime(2026, 10, 1)),
    ];
    final rnd = Random(1);
    expect(buildNagaraPool(NagaraSource.all, questions: qs, history: history, random: rnd),
        hasLength(3));
    expect(
        buildNagaraPool(NagaraSource.recentSubject, questions: qs, history: history, random: rnd)
            .map((q) => q.qid),
        ['b']);
    expect(
        buildNagaraPool(NagaraSource.recentSubject, questions: qs, history: const [], random: rnd),
        hasLength(3));
    expect(
        buildNagaraPool(NagaraSource.mistakes,
                questions: qs, history: history, mistakeQids: {'a'}, random: rnd)
            .map((q) => q.qid),
        ['a']);
    final nq = toNagaraQuestions([qs.first], random: rnd).single;
    expect(nq.choices[nq.correctIndex], 'aの正解');
  });

  testWidgets('設定: 考える間・次までの間・自動で次へ・解説を読む が保存される', (tester) async {
    final env = await _env(tester, const SettingsScreen());
    final notifier = env.container.read(handsFreeProvider.notifier);
    await notifier.load();
    await tester.pump();

    Future<void> pick(String key, String label) async {
      final tile = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.descendant(of: tile, matching: find.byType(DropdownButton<int>)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await pick('nagara-think', '12 秒');
    await pick('nagara-between', '5 秒');
    expect(env.container.read(handsFreeProvider).thinkSeconds, 12);
    expect(env.container.read(handsFreeProvider).betweenSeconds, 5);

    await tester.scrollUntilVisible(find.text('自動で次へ進む'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('自動で次へ進む'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('解説を読む'));
    await tester.pumpAndSettle();

    final saved = env.container.read(handsFreeProvider);
    expect(saved.autoAdvance, isFalse);
    expect(saved.speakExplanation, isFalse);
    final json = await env.store.read();
    expect(json?['thinkSeconds'], 12);
    expect(json?['betweenSeconds'], 5);
    expect(json?['autoAdvance'], false);
    expect(json?['speakExplanation'], false);
  });
}
