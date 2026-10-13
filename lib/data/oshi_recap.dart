import 'package:ukalab_core/ukalab_core.dart';

import 'progress_store.dart';

/// 推しの一言・週間ふりかえりに渡す入力を、アプリの既存データ(解答履歴・連続学習・試験日)から作る。
/// 文言・判定は ukalab_core 側。ここは入力を作るだけ(個人情報・問題IDは入れない)。

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// 推しの一言の状況。[now] は「今日」の基準(テストで固定できる)。
OshiMessageContext oshiMessageContextFor({
  required List<ProgressRecord> records,
  required ProgressState progress,
  required DateTime now,
  DateTime? examDate,
}) {
  final today = _day(now);

  DateTime? lastStudy;
  var todayAnswered = 0;
  var todayCorrect = 0;
  for (final r in records) {
    final d = _day(r.at);
    if (lastStudy == null || d.isAfter(lastStudy)) lastStudy = d;
    if (d == today) {
      todayAnswered++;
      if (r.correct) todayCorrect++;
    }
  }
  // 履歴が空でも(旧データなど)連続学習の最終学習日があれば使う。
  final stored = progress.lastStudyDay == null ? null : DateTime.tryParse(progress.lastStudyDay!);
  if (stored != null && (lastStudy == null || _day(stored).isAfter(lastStudy))) {
    lastStudy = _day(stored);
  }
  final since = lastStudy == null ? null : today.difference(lastStudy).inDays;

  int? examDaysLeft;
  if (examDate != null) {
    final left = _day(examDate).difference(today).inDays;
    if (left >= 0) examDaysLeft = left;
  }

  return OshiMessageContext(
    daysSinceLastStudy: since == null || since < 0 ? null : since,
    // 連続日数は「今日か昨日まで続いている」ときだけ使う(途切れた古い値で褒めない)。
    streakDays: since != null && since <= 1 ? progress.streakDays : 0,
    todayAnswered: todayAnswered,
    todayCorrectRate: todayAnswered == 0 ? null : todayCorrect / todayAnswered,
    examDaysLeft: examDaysLeft,
    hasWeakTopics: computeWeakTopics(records, now: now, byChapter: true).isNotEmpty,
  );
}

/// 週間ふりかえり(今週。月曜始まり)。メダルは獲得日を持たないため数えない(0)。
WeeklyRecap weeklyRecapFor({
  required List<ProgressRecord> records,
  required DateTime now,
}) =>
    const WeeklyRecapEngine(weekStartsOn: DateTime.monday)
        .build(weeklyRecapDaysFromRecords(records), weekOf: now);

/// 分野(topicId)の表示名。topicId は細かい論点のslugなので、その問題の科目名で表す。
/// 見つからなければ ID をそのまま返す。
String Function(String topicId) topicLabelFor(
  List<Question> questions,
  String? Function(String subjectId) subjectName,
) {
  final byTopic = <String, String>{};
  for (final q in questions) {
    final name = subjectName(q.subjectId);
    if (name != null) byTopic.putIfAbsent(q.topicId, () => name);
  }
  return (id) => byTopic[id] ?? id;
}
