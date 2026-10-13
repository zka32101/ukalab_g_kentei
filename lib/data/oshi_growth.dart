import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'core_features.dart';
import 'progress_store.dart';

/// 推しの成長演出の「祝い済みの節目」の保存先(端末内。キー `ukalab_oshi_growth_g_kentei`)。
final OshiGrowthStore oshiGrowthStore = SharedPreferencesOshiGrowthStore(kExamId);

/// 既存の統計から、推しの成長演出に渡す累計を作る(個人情報・問題IDは入れない)。
///
/// - 回答数: 解答履歴の件数と、解いた問題の種類数([ProgressState.distinctAnswered])の大きい方。
///   履歴は直近 [historyMaxRecords] 件までなので、それを超えても累計が減らないように後者も見る。
/// - 学習日数: 履歴にある日の種類数(連続ではなく合計)。履歴が無くても連続学習日数・最終学習日の分は数える。
OshiGrowthProgress oshiGrowthProgressFor({
  required List<ProgressRecord> records,
  required ProgressState progress,
}) {
  final days = <String>{for (final r in records) studyDayKey(r.at)};
  final last = progress.lastStudyDay;
  if (last != null) days.add(last);
  return OshiGrowthProgress(
    totalAnswered: records.length > progress.distinctAnswered
        ? records.length
        : progress.distinctAnswered,
    studyDays: days.length > progress.streakDays ? days.length : progress.streakDays,
  );
}
