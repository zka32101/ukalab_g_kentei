import 'package:ukalab_core/daily_goal.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'history_store.dart';
import 'progress_store.dart';

/// 設定タブの「データの管理」（書き出し・読み込み・リセット）の対象。
///
/// 学習進捗（解答済みの問題・模擬試験の合格・連続学習日数）、解答履歴、
/// デイリーミッション（目標・達成履歴）、自分用メモが対象。試験日・ブックマークは設定・整理物として含めない。
final List<DataPart> gKenteiDataParts = [
  DataPart(
    id: 'progress',
    export: (ref) {
      final p = ref.read(progressProvider);
      return {
        'answered': p.answeredQidToCorrect,
        'mockPassedEver': p.mockPassedEver,
        'lastStudyDay': p.lastStudyDay,
        'streakDays': p.streakDays,
      };
    },
    restore: (ref, json) {
      final m = json as Map<String, dynamic>;
      return ref.read(progressProvider.notifier).replace(ProgressState(
            answeredQidToCorrect: (m['answered'] as Map<String, dynamic>).cast<String, bool>(),
            mockPassedEver: m['mockPassedEver'] as bool? ?? false,
            lastStudyDay: m['lastStudyDay'] as String?,
            streakDays: m['streakDays'] as int? ?? 0,
          ));
    },
    reset: (ref) => ref.read(progressProvider.notifier).reset(),
  ),
  DataPart(
    id: 'history',
    export: (ref) => encodeHistory(ref.read(historyProvider)),
    restore: (ref, json) => ref.read(historyProvider.notifier).replace(decodeHistory(json as String?)),
    reset: (ref) => ref.read(historyProvider.notifier).reset(),
  ),
  DataPart(
    id: 'dailyGoal',
    export: (ref) => ref.read(dailyGoalProvider).toJson(),
    restore: (ref, json) =>
        ref.read(dailyGoalProvider.notifier).restore(DailyGoal.fromJson(json as Map<String, dynamic>)),
    reset: (ref) => ref.read(dailyGoalProvider.notifier).reset(),
  ),
  DataPart(
    id: 'dailyGoalHistory',
    export: (ref) => [for (final e in ref.read(dailyGoalHistoryProvider)) e.toJson()],
    restore: (ref, json) => ref.read(dailyGoalHistoryProvider.notifier).restore([
      for (final j in (json as List).cast<Map<String, dynamic>>()) DailyGoalHistoryEntry.fromJson(j),
    ]),
    reset: (ref) => ref.read(dailyGoalHistoryProvider.notifier).reset(),
  ),
  DataPart(
    id: 'questionMemo',
    export: (ref) => ref.read(questionMemoProvider),
    restore: (ref, json) =>
        ref.read(questionMemoProvider.notifier).restore((json as Map<String, dynamic>).cast<String, String>()),
    reset: (ref) => ref.read(questionMemoProvider.notifier).reset(),
  ),
];
