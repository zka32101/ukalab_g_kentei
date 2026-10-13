import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_g_kentei/data/core_features.dart';
import 'package:ukalab_g_kentei/data/data_parts.dart';
import 'package:ukalab_g_kentei/screens/exam_prep_entry.dart';

import 'test_support.dart';

final _now = DateTime(2026, 10, 13);

ExamConfig _exam() => ExamConfig(
      examId: 'g_kentei',
      name: 'G検定',
      audience: Audience.adult,
      subjects: const [],
      levels: const [],
      examDates: const [],
    );

Question _q(String qid) => Question(
      qid: qid,
      examId: 'g_kentei',
      subjectId: 's1',
      topicId: 'ch1',
      prompt: 'prompt-$qid',
      choices: const ['a', 'b'],
      answerIndex: 0,
      explanation: 'e',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

Future<ProviderContainer> _pumpCard(WidgetTester tester,
    {required DateTime? examDate, bool premium = false}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
    ...studyNotesTestOverrides(),
    adGateProvider.overrideWithValue(await testAdGate()),
    entitlementStateProvider.overrideWith(
        (ref) => Stream.value(EntitlementState(hasPremium: premium))),
  ]);
  addTearDown(container.dispose);
  await container.read(examDateProvider.notifier).setDate(examDate);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: CoreFeaturesCard(
          exam: _exam(),
          questions: [for (var i = 0; i < 20; i++) _q('q$i')],
          terms: const [],
          clock: () => _now,
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('更新ログ・チェックリストの同梱データが読めて、検証を通る', () async {
    final log = await loadUpdateLog(now: _now);
    expect(log, hasLength(3));
    for (var i = 1; i < log.length; i++) {
      expect(log[i - 1].date.isBefore(log[i].date), isFalse);
    }
    expect(validateUpdateLog(log), isEmpty);
    final items = await loadChecklist();
    expect(items.length, greaterThanOrEqualTo(5));
    // 公式で確認できていない項目は、未確認のまま(断定しない)
    expect(unconfirmedItems(items), hasLength(items.length));
    expect(items.map((i) => i.category).toSet(), containsAll([
      ChecklistCategory.environment,
      ChecklistCategory.admission,
    ]));
  });

  testWidgets('チェックリスト: チェックが進捗に反映され、保存され、データ管理の対象になる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final items = await tester.runAsync(loadChecklist) ?? [];
    late WidgetRef wref;
    await tester.pumpWidget(ProviderScope(
      child: Consumer(builder: (context, ref, _) {
        wref = ref;
        return MaterialApp(
            home: ExamDayChecklistView(
          examId: kExamId,
          items: items,
          venue: ExamVenueKind.online,
          initialProgress: ref.read(checklistProvider),
          onChanged: ref.read(checklistProvider.notifier).setProgress,
        ));
      }),
    ));
    await tester.pump();
    expect(find.text(ExamPrepStrings.ja.confirmNeeded), findsWidgets);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getStringList('ukalab_g_kentei_exam_checklist_v1'), hasLength(1));
    final part = gKenteiDataParts.firstWhere((p) => p.id == 'examChecklist');
    expect(part.export(wref), hasLength(1));
    await tester.runAsync(() => part.reset(wref));
    expect(wref.read(checklistProvider).checkedIds, isEmpty);
    await tester.runAsync(() => part.restore(wref, ['a', 'b']));
    expect(wref.read(checklistProvider).checkedIds, {'a', 'b'});
  });

  testWidgets('更新ログ: 新しい順に表示、空なら穏やかな文言', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: UpdateLogView(
          entriesFuture: Future.value([
        UpdateLogEntry(
            entryId: 'a',
            examId: kExamId,
            date: DateTime(2026, 10, 10),
            kind: UpdateKind.correction,
            title: '訂正しました'),
      ])),
    ));
    await tester.pump();
    expect(find.text('訂正しました'), findsOneWidget);
    await tester.pumpWidget(
        MaterialApp(home: UpdateLogView(entriesFuture: Future.value([]))));
    await tester.pump();
    expect(find.text(ExamPrepStrings.ja.updateLogEmpty), findsOneWidget);
  });

  testWidgets('ホームのカード: 試験日が遠いと直前モードは出ず、近いと出る', (tester) async {
    await _pumpCard(tester, examDate: null);
    expect(find.byKey(const ValueKey('tenMinPlanTile')), findsOneWidget);
    expect(find.byKey(const ValueKey('examEveTile')), findsNothing);
    expect(find.byKey(const ValueKey('checklistTile')), findsNothing);

    await _pumpCard(tester, examDate: DateTime(2026, 10, 15));
    expect(find.byKey(const ValueKey('examEveTile')), findsOneWidget);
    expect(find.byKey(const ValueKey('checklistTile')), findsOneWidget);
  });

  testWidgets('10分プラン: 無料は案内のみ、premiumは練習画面が開く', (tester) async {
    await _pumpCard(tester, examDate: null);
    await tester.tap(find.byKey(const ValueKey('tenMinPlanTile')));
    await tester.pump();
    expect(find.text('prompt-q0'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);

    await _pumpCard(tester, examDate: null, premium: true);
    await tester.tap(find.byKey(const ValueKey('tenMinPlanTile')));
    await tester.pumpAndSettle();
    expect(find.byType(AppBar), findsOneWidget);
  });

  test('premium制限はcoreのPremiumFeatureに従う', () {
    for (final f in [
      PremiumFeature.tenMinutePlan,
      PremiumFeature.examEveMode,
      PremiumFeature.historyExport,
    ]) {
      expect(canUsePremiumFeature(f, isPremium: false), isFalse);
      expect(canUsePremiumFeature(f, isPremium: true), isTrue);
    }
  });
}
