import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/progress_store.dart';
import '../screens/settings_screen.dart';
import 'oshi_medal_button.dart';

/// 網羅率＝解いた問題の種類数÷全問題数、正答率＝qidごとの最新の正誤に基づく
/// 正答率から習得度の入力を作る。`ReadinessRule.isReady` にそのまま渡せる。
MasteryInput masteryInputFor({
  required int distinctAnswered,
  required int totalQuestions,
  required int correct,
}) {
  if (totalQuestions <= 0 || distinctAnswered <= 0) {
    return const MasteryInput(coverage: 0, accuracy: 0);
  }
  final coverage = (distinctAnswered / totalQuestions).clamp(0.0, 1.0);
  final accuracy = (correct / distinctAnswered).clamp(0.0, 1.0);
  return MasteryInput(coverage: coverage, accuracy: accuracy);
}

/// 習得度から推しの成長段階を決める。
MascotStage oshiStageFor({
  required int distinctAnswered,
  required int totalQuestions,
  required int correct,
}) {
  final mastery = masteryInputFor(
    distinctAnswered: distinctAnswered,
    totalQuestions: totalQuestions,
    correct: correct,
  );
  return MasteryModel.standard.stageOf(mastery);
}

/// ホームの「推し」カード。共通キットの [UkalabOshiCard] に、G検定の成長段階・連続日数・
/// 試験日を渡す。推しの選択・着替え・合格報告・表示切替・コイン表示はキット側。
class OshiCard extends ConsumerWidget {
  const OshiCard({
    super.key,
    required this.totalQuestions,
    this.examDate,
    this.settingsBuilder,
  });

  /// 設定画面を作る関数。ロック中の資格専用キャラ（ノーダ）のプレビューで「プレミアムを見る」が
  /// 押されたとき、設定（購入欄）を開くために使う。null なら引数なしの [SettingsScreen] を開く。
  final Widget Function()? settingsBuilder;

  /// 出題範囲の全問題数（網羅率の分母）。
  final int totalQuestions;

  /// 試験日（設定した人だけ）。
  final DateTime? examDate;

  /// 推しの選択画面を閉じて、設定（購入欄）を画面として開く。
  /// 下部タブの切り替えは [UkalabShell] の内部状態で外から操作できないため、画面を push する。
  void _openSettings(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('設定')),
          body: SafeArea(child: (settingsBuilder ?? () => const SettingsScreen())()),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final now = DateTime.now();
    // 共通キットのカードのメニューには項目を足せないため、メダルの入口はカードのすぐ下に置く。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UkalabOshiCard(
          cert: UkalabCert.gKentei,
          stage: oshiStageFor(
            distinctAnswered: progress.distinctAnswered,
            totalQuestions: totalQuestions,
            correct: progress.correctCount,
          ),
          appId: 'g_kentei',
          examDate: examDate,
          streakDays: progress.streakDays,
          studiedToday: progress.lastStudyDay == studyDayKey(now),
          onLockedTap: () => _openSettings(context),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: OshiMedalButton(totalQuestions: totalQuestions),
        ),
      ],
    );
  }
}
