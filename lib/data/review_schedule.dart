import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'core_features.dart';
import 'mistake_notes.dart';

/// 「今日の復習」の復習予定の保存先(端末内。キー `ukalab_g_kentei_review_schedule`)。
/// 間違いノートから作る派生データで、バックアップ/リセットの対象([gKenteiDataParts] の `reviewSchedule`)。
final ReviewSchedulerStore reviewSchedulerStore = SharedPreferencesReviewSchedulerStore(kExamId);

const ReviewSchedulerEngine reviewSchedulerEngine = ReviewSchedulerEngine();

/// 間違いノートから復習予定を同期して保存し、返す(冪等)。
///
/// [records] の新しい間違いも反映するが、間違いノート自体は書き換えない
/// (ノート画面側の「克服」のお祝い判定を横取りしないため)。
/// 出題データに無い問題は除く(ノート画面と同じ扱い)。
Future<List<ReviewItem>> syncReviewSchedule({
  required List<ProgressRecord> records,
  required Set<String> knownQids,
  MistakeNoteStore? noteStore,
  ReviewSchedulerStore? reviewStore,
}) async {
  final notes = await (noteStore ?? mistakeNoteStore).read();
  final latest = mistakeNoteEngine.update(notes, records);
  final usable = [for (final e in latest) if (knownQids.contains(e.qid)) e];
  final store = reviewStore ?? reviewSchedulerStore;
  final items = reviewSchedulerEngine.sync(await store.read(), usable);
  await store.write(items);
  return items;
}

/// 1問の解答結果を復習予定に反映する。予定に無い問題は何も変えない。
/// [at] は履歴の `ProgressRecord.at` と同じ時刻を渡す(core の docs/review_scheduler.md)。
/// 失敗しても解答の記録は止めない。
Future<void> applyReviewResult(
  String qid, {
  required bool correct,
  required DateTime at,
  ReviewSchedulerStore? store,
}) async {
  try {
    final s = store ?? reviewSchedulerStore;
    final items = await s.read();
    if (!items.any((i) => i.qid == qid)) return;
    await s.write(reviewSchedulerEngine.applyResult(items, qid, correct: correct, now: at));
  } catch (_) {}
}
