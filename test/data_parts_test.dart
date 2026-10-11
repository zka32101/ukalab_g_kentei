import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ui.dart' show encodeLearningDataBackup, resetLearningData, restoreLearningDataBackup;
import 'package:ukalab_g_kentei/data/data_parts.dart';
import 'package:ukalab_g_kentei/data/progress_store.dart';

import 'test_support.dart';

void main() {
  test('パーツのidは重複しない', () {
    final ids = [for (final p in gKenteiDataParts) p.id];
    expect(ids, ['progress', 'history', 'questionMemo']);
  });

  testWidgets('学習進捗を書き出し→リセット→読み込みで戻せる', (tester) async {
    SharedPreferences.setMockInitialValues({});
    late WidgetRef ref;
    await tester.pumpWidget(ProviderScope(
      overrides: studyNotesTestOverrides(),
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(builder: (context, r, _) {
            ref = r;
            return const SizedBox();
          }),
        ),
      ),
    ));
    await tester.runAsync(() async {
      await ref.read(progressProvider.notifier).replace(const ProgressState(
            answeredQidToCorrect: {'q1': true, 'q2': false},
            mockPassedEver: true,
            lastStudyDay: '2026-10-06',
            streakDays: 3,
          ));
      final text = encodeLearningDataBackup(ref, gKenteiDataParts);

      await resetLearningData(ref, gKenteiDataParts);
      expect(ref.read(progressProvider).answeredQidToCorrect, isEmpty);
      expect(ref.read(progressProvider).streakDays, 0);

      await restoreLearningDataBackup(ref, gKenteiDataParts, text);
      final p = ref.read(progressProvider);
      expect(p.answeredQidToCorrect, {'q1': true, 'q2': false});
      expect(p.mockPassedEver, isTrue);
      expect(p.lastStudyDay, '2026-10-06');
      expect(p.streakDays, 3);
    });
  });
}
