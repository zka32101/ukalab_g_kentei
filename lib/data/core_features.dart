import 'package:app_common_kit/app_common_kit.dart'
    show EntitlementState, entitlementStateProvider;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart';

/// ukalab_core の共通機能（更新ログ・試験直前・10分プラン・当日チェックリスト・履歴の書き出し）を
/// このアプリのデータにつなぐ部分。画面は `lib/screens/exam_prep_entry.dart` 側。

/// 試験定義の examId（`assets/exam/g_kentei.json`）。
const String kExamId = 'g_kentei';

const String updateLogAsset = 'assets/features/update_log.jsonl';
const String checklistAsset = 'assets/features/checklist.jsonl';

/// 更新ログ（新しい順。未来の予定と90日より前は除く）。
Future<List<UpdateLogEntry>> loadUpdateLog(
    {DateTime? now, AssetBundle? bundle}) async {
  final text = await (bundle ?? rootBundle).loadString(updateLogAsset);
  return recentUpdates(parseUpdateLogJsonl(text).entries, now ?? DateTime.now(),
      examId: kExamId);
}

/// 当日チェックリスト（オンライン受験。分類順）。全項目「公式で要確認」。
Future<List<ChecklistItem>> loadChecklist({AssetBundle? bundle}) async {
  final text = await (bundle ?? rootBundle).loadString(checklistAsset);
  return checklistFor(kExamId, parseChecklistItemsJsonl(text).items,
      venue: ExamVenueKind.online);
}

/// プレミアムか（試験直前・10分プラン・履歴の書き出しの利用可否）。
bool isPremiumFor(WidgetRef ref, PremiumFeature feature) =>
    canUsePremiumFeature(
      feature,
      isPremium: (ref.watch(entitlementStateProvider).valueOrNull ??
              EntitlementState.free)
          .hasPremium,
    );

/// 当日チェックリストのチェック状態(端末内)。
class ChecklistNotifier extends Notifier<ChecklistProgress> {
  static const _key = 'ukalab_g_kentei_exam_checklist_v1';
  late Future<void> _loaded;

  /// 保存済みの状態を読み終えたとき。
  Future<void> get ready => _loaded;

  @override
  ChecklistProgress build() {
    _loaded = _load();
    return const ChecklistProgress();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_key);
      if (ids != null) state = ChecklistProgress({...ids, ...state.checkedIds});
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, state.checkedIds.toList()..sort());
    } catch (_) {}
  }

  /// 共通画面の変更通知から呼ぶ(チェック状態をまるごと置き換える)。
  Future<void> setProgress(ChecklistProgress p) async {
    await _loaded;
    state = p;
    await _save();
  }

  /// バックアップの読み込み用。
  Future<void> restore(Iterable<String> ids) =>
      setProgress(ChecklistProgress(ids.toSet()));

  /// リセット用。
  Future<void> reset() => setProgress(const ChecklistProgress());
}

final checklistProvider =
    NotifierProvider<ChecklistNotifier, ChecklistProgress>(
        ChecklistNotifier.new);
