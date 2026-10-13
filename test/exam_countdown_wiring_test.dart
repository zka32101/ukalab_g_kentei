import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_g_kentei/screens/exam_prep_entry.dart';

final _now = DateTime(2026, 10, 13);

ExamConfig _exam({List<DateTime> dates = const []}) => ExamConfig(
      examId: 'g_kentei',
      name: 'G検定',
      audience: Audience.adult,
      subjects: const [],
      levels: const [],
      examDates: dates,
    );

Future<ProviderContainer> _pump(WidgetTester tester,
    {DateTime? userDate, ExamConfig? exam}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await container.read(examDateProvider.notifier).setDate(userDate);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: ExamCountdownEntry(exam: exam ?? _exam(), clock: () => _now),
      ),
    ),
  ));
  await tester.pump();
  return container;
}

String _chip(int offsetDays) => ExamCountdownStrings.ja.chip(
    const ExamCountdownEngine().compute(
        _now.add(Duration(days: offsetDays)), today: _now));

void main() {
  testWidgets('試験日が未設定なら何も出ない', (tester) async {
    await _pump(tester);
    expect(find.byType(ExamCountdownChip), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
  });

  testWidgets('設定済みならチップが出る(各 phase の代表値)', (tester) async {
    for (final d in [200, 50, 20, 3, 0]) {
      await _pump(tester, userDate: _now.add(Duration(days: d)));
      expect(find.byType(ExamCountdownChip), findsOneWidget, reason: '$d');
      expect(find.text(_chip(d)), findsOneWidget, reason: '$d');
    }
    // 日数の代表値が phase ごとに違う文言になる
    expect(_chip(3), isNot(_chip(20)));
    expect(_chip(0), ExamCountdownStrings.ja.chipToday);
  });

  testWidgets('試験日を過ぎたら日数を出さず おつかれさまでした', (tester) async {
    await _pump(tester, userDate: _now.subtract(const Duration(days: 1)));
    expect(find.text('おつかれさまでした'), findsOneWidget);
    expect(find.textContaining('日'), findsNothing);
  });

  testWidgets('ユーザー設定が無ければ公式日程の先頭を使う', (tester) async {
    await _pump(tester,
        exam: _exam(dates: [_now.add(const Duration(days: 20))]));
    expect(find.text(_chip(20)), findsOneWidget);
  });

  testWidgets('タップで試験日の設定画面が開き、そこで変えた日付がチップに反映される', (tester) async {
    final container =
        await _pump(tester, userDate: _now.add(const Duration(days: 20)));
    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    expect(find.text('試験日の設定'), findsOneWidget);
    expect(find.byType(ExamDateTile), findsOneWidget);
    await container
        .read(examDateProvider.notifier)
        .setDate(_now.add(const Duration(days: 3)));
    await tester.pumpAndSettle();
    expect(find.text(_chip(3)), findsOneWidget);
  });
}
