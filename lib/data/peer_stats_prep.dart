import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart'
    show PeerStatsSettings, ProgressRecord;

import 'progress_store.dart';

// 匿名の仲間集計(PeerStats)の「下準備」だけ。端末から外へ送る処理は無い。
// ここにある関数・クラスは、まだどの画面・処理からも呼ばれていない(接続しない)。

/// 連続学習日数(今日を含む)。既存の [ProgressState.streakDays] をそのまま返す。
int peerStreakDays(ProgressState progress) => progress.streakDays;

/// 累計問題数の候補(1)「延べ回答数」: 解答履歴の件数。履歴は直近の上限件数までしか残らない。
/// どちらを送るかは未決(PR 本文の未決事項を参照)。
int peerTotalAnsweredCount(List<ProgressRecord> records) => records.length;

/// 累計問題数の候補(2)「ユニーク問題数」: 一度でも解いた問題の種類数。
int peerDistinctQuestionCount(ProgressState progress) => progress.distinctAnswered;

/// 試験日を `yyyy-MM-dd` にする。未設定は null。
String? peerExamDateKey(DateTime? examDate) => examDate == null ? null : studyDayKey(examDate);

/// 送信の同意(既定OFF)の保存先。端末内の SharedPreferences だけを使う。
class SharedPreferencesPeerStatsSettings implements PeerStatsSettings {
  const SharedPreferencesPeerStatsSettings();

  static const key = 'ukalab_g_kentei_peer_stats_sharing_v1';

  @override
  Future<bool> isSharingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? false;
  }

  @override
  Future<void> setSharingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, enabled);
  }
}

final peerStatsSettingsProvider =
    Provider<PeerStatsSettings>((ref) => const SharedPreferencesPeerStatsSettings());
