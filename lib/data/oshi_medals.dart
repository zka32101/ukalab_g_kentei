import 'package:ukalab_core/achievements.dart' show Achievement;
import 'package:ukalab_core/ui.dart' show OshiMedal, OshiMedalKind;

/// 連続学習日数の節目（コイン付与の節目と同じ）。
const medalStreakMilestones = [7, 30, 100];

/// 既存の記録からメダルを作る。**個人情報は入れない**（id・文言・段階・種類のみ）。
///
/// - 連続学習: 到達した最大の節目 1 つ（7日=銅・30日=銀・100日=金）
/// - 模擬試験: 目安の正答率を超えたことがあれば 1 つ
/// - 実績: 解除済みの実績ごとに 1 つ
/// 画像は付けない（コード描画）。後でアセットに差し替える。
List<OshiMedal> buildOshiMedals({
  required int streakDays,
  required bool mockPassed,
  Iterable<Achievement> achievements = const [],
}) {
  final medals = <OshiMedal>[];
  var tier = 0;
  var reached = 0;
  for (var i = 0; i < medalStreakMilestones.length; i++) {
    if (streakDays >= medalStreakMilestones[i]) {
      tier = i + 1;
      reached = medalStreakMilestones[i];
    }
  }
  if (tier > 0) {
    medals.add(OshiMedal(
      id: 'streak_$reached',
      label: '$reached日連続で学習',
      tier: tier,
      kind: OshiMedalKind.streak,
    ));
  }
  if (mockPassed) {
    medals.add(const OshiMedal(
      id: 'mock_pass',
      label: '模擬試験で目安の正答率を超えた',
      tier: 2,
      kind: OshiMedalKind.mockPass,
    ));
  }
  for (final a in achievements.where((a) => a.unlocked)) {
    medals.add(OshiMedal(
      id: 'achievement_${a.id}',
      label: a.title,
      kind: OshiMedalKind.achievement,
    ));
  }
  return medals;
}
