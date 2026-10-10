import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 現在時刻の取得元。連続学習日数の判定をテストで固定するために差し替える。
final progressClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// 日付部分だけの識別子（'yyyy-MM-dd'）。
String studyDayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

/// 連続学習日数のコイン付与の節目（`CoinRules.streak7/30/100` に対応）。
const streakCoinMilestones = [7, 30, 100];

/// 推し（マスコット）の成長段階を計算するための、軽量な学習進捗。
///
/// qid ごとに最新の正誤だけを保持する（履歴は持たない）。苦手分析・間隔反復
/// などの本格的な学習記録は後続で別途用意する。[mockPassedEver] は
/// 「準備完了」の判定（決定67〜77、`ReadinessRule`）に使う。[lastStudyDay]・
/// [streakDays] は連続学習日数（決定29）とそのコイン付与（決定67〜77）に使う。
class ProgressState {
  const ProgressState({
    this.answeredQidToCorrect = const {},
    this.mockPassedEver = false,
    this.lastStudyDay,
    this.streakDays = 0,
  });

  final Map<String, bool> answeredQidToCorrect;

  /// 模擬試験で合格点を一度でも超えたか。
  final bool mockPassedEver;

  /// 最後に学習した日（'yyyy-MM-dd'）。未学習なら null。
  final String? lastStudyDay;

  /// 連続学習日数（今日を含む）。未学習なら0。
  final int streakDays;

  int get distinctAnswered => answeredQidToCorrect.length;
  int get correctCount => answeredQidToCorrect.values.where((c) => c).length;
}

class ProgressNotifier extends Notifier<ProgressState> {
  static const _key = 'ukalab_g_kentei_progress_v1';
  static const _mockPassedKey = 'ukalab_g_kentei_mock_passed_ever_v1';
  static const _lastStudyDayKey = 'ukalab_g_kentei_last_study_day_v1';
  static const _streakDaysKey = 'ukalab_g_kentei_streak_days_v1';

  late Future<void> _loaded;

  @override
  ProgressState build() {
    _loaded = _load();
    return const ProgressState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final mockPassedEver = prefs.getBool(_mockPassedKey) ?? false;
    final lastStudyDay = prefs.getString(_lastStudyDayKey);
    final streakDays = prefs.getInt(_streakDaysKey) ?? 0;
    if (raw == null) {
      state = ProgressState(
        mockPassedEver: mockPassedEver,
        lastStudyDay: lastStudyDay,
        streakDays: streakDays,
      );
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      state = ProgressState(
        answeredQidToCorrect: decoded.map((k, v) => MapEntry(k, v as bool)),
        mockPassedEver: mockPassedEver,
        lastStudyDay: lastStudyDay,
        streakDays: streakDays,
      );
    } catch (_) {
      // 壊れた保存データは無視して空の状態から始める。
      state = ProgressState(
        mockPassedEver: mockPassedEver,
        lastStudyDay: lastStudyDay,
        streakDays: streakDays,
      );
    }
  }

  /// 学習した日を記録し、連続学習日数を更新する（決定29）。同じ日の2回目
  /// 以降は変化しない。前日から続いていれば+1、空いていれば1から数え直す。
  /// 「学ぶ」タブの解答・模擬試験の実施のどちらからも呼ぶ。
  Future<void> touchStudyDay() async {
    await _loaded;
    final now = ref.read(progressClockProvider)();
    final today = studyDayKey(now);
    if (state.lastStudyDay == today) return;

    final yesterday = studyDayKey(now.subtract(const Duration(days: 1)));
    final streak = state.lastStudyDay == yesterday ? state.streakDays + 1 : 1;

    state = ProgressState(
      answeredQidToCorrect: state.answeredQidToCorrect,
      mockPassedEver: state.mockPassedEver,
      lastStudyDay: today,
      streakDays: streak,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastStudyDayKey, today);
    await prefs.setInt(_streakDaysKey, streak);
  }

  Future<void> recordAnswer(String qid, {required bool correct}) async {
    await touchStudyDay();
    state = ProgressState(
      answeredQidToCorrect: {...state.answeredQidToCorrect, qid: correct},
      mockPassedEver: state.mockPassedEver,
      lastStudyDay: state.lastStudyDay,
      streakDays: state.streakDays,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.answeredQidToCorrect));
  }

  /// 模擬試験の結果を記録する。[passed] が true なら [mockPassedEver] を立てる
  /// （一度立てば下がらない）。
  Future<void> recordMockResult({required bool passed}) async {
    await _loaded;
    if (!passed || state.mockPassedEver) return;
    state = ProgressState(
      answeredQidToCorrect: state.answeredQidToCorrect,
      mockPassedEver: true,
      lastStudyDay: state.lastStudyDay,
      streakDays: state.streakDays,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mockPassedKey, true);
  }

  /// バックアップの読み込み時に呼ぶ。[snapshot] で上書きする。
  Future<void> replace(ProgressState snapshot) async {
    await _loaded;
    state = snapshot;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(snapshot.answeredQidToCorrect));
    await prefs.setBool(_mockPassedKey, snapshot.mockPassedEver);
    final day = snapshot.lastStudyDay;
    if (day == null) {
      await prefs.remove(_lastStudyDayKey);
    } else {
      await prefs.setString(_lastStudyDayKey, day);
    }
    await prefs.setInt(_streakDaysKey, snapshot.streakDays);
  }

  /// 学習進捗をすべて消す。
  Future<void> reset() async {
    await _loaded;
    state = const ProgressState();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_mockPassedKey);
    await prefs.remove(_lastStudyDayKey);
    await prefs.remove(_streakDaysKey);
  }
}

final progressProvider = NotifierProvider<ProgressNotifier, ProgressState>(
  ProgressNotifier.new,
);
