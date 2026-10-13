import 'package:app_common_kit/app_common_kit.dart' show ExamDateTile;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/exam_date.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/core_features.dart';
import '../data/history_store.dart';
import 'learn_screen.dart';

/// ukalab_core の共通画面(`lib/ui/exam_prep/`)をこのアプリのデータにつなぐ部分。
/// 画面・文言は core 側。ここは取得・保存・premium 判定・遷移だけ。

/// ホームの「試験に向けて」カード。
class CoreFeaturesCard extends ConsumerWidget {
  const CoreFeaturesCard({
    super.key,
    required this.exam,
    required this.questions,
    required this.terms,
    this.clock = DateTime.now,
  });

  final ExamConfig exam;
  final List<Question> questions;
  final List<Term> terms;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExamPrepCard(
      clock: clock,
      questions: () => questions,
      records: () => ref.read(historyProvider),
      examDate: effectiveExamDates(ref.watch(examDateProvider), exam.examDates)
          .firstOrNull,
      tenMinUnlocked: isPremiumFor(ref, PremiumFeature.tenMinutePlan),
      examEveUnlocked: isPremiumFor(ref, PremiumFeature.examEveMode),
      onStartPractice: (c, title, pool, empty) {
        if (pool.isEmpty) {
          ScaffoldMessenger.of(c)
              .showSnackBar(SnackBar(content: Text(empty)));
          return;
        }
        Navigator.of(c).push(MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(title)),
            body: LearnScreen(
                questions: pool, terms: terms, sessionSize: pool.length),
          ),
        ));
      },
      onOpenChecklist: (c) async {
        final notifier = ref.read(checklistProvider.notifier);
        await notifier.ready;
        if (!c.mounted) return;
        final items = await loadChecklist();
        if (!c.mounted) return;
        await Navigator.of(c).push(MaterialPageRoute<void>(
          builder: (_) => ExamDayChecklistView(
            examId: kExamId,
            items: items,
            venue: ExamVenueKind.online,
            initialProgress: ref.read(checklistProvider),
            onChanged: notifier.setProgress,
          ),
        ));
      },
    );
  }
}

/// ホームの試験日カウントダウン(チップ)。無料。未設定なら何も出ない(core の仕様)。
/// 日付は「試験に向けて」カードと同じ(ユーザー設定を優先、なければ公式日程の先頭)。
/// タップで試験日の設定画面([openExamDateSettings])を開く。
class ExamCountdownEntry extends ConsumerWidget {
  const ExamCountdownEntry({
    super.key,
    required this.exam,
    this.clock = DateTime.now,
  });

  final ExamConfig exam;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = effectiveExamDates(ref.watch(examDateProvider), exam.examDates)
        .firstOrNull;
    if (date == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ExamCountdownChip(
          examDate: date,
          clock: clock,
          onTap: () => openExamDateSettings(context),
        ),
      ),
    );
  }
}

/// 試験日の設定画面。設定タブの試験日タイルと同じタイル(同じ日付ピッカー・同じ保存先)を開く。
Future<void> openExamDateSettings(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('試験日の設定')),
        body: Consumer(
          builder: (context, ref, _) => ListView(children: [
            ExamDateTile(
              date: ref.watch(examDateProvider),
              onChanged: (d) => ref.read(examDateProvider.notifier).setDate(d),
            ),
          ]),
        ),
      ),
    ));

/// 設定タブの、更新ログ・履歴書き出しの入口。
class CoreFeatureSettingsTiles extends ConsumerWidget {
  const CoreFeatureSettingsTiles({super.key, required this.questions});

  final List<Question> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExamPrepSettingsTiles(
      exportUnlocked: isPremiumFor(ref, PremiumFeature.historyExport),
      onOpenUpdateLog: (c) => Navigator.of(c).push(MaterialPageRoute<void>(
          builder: (_) => UpdateLogView(entriesFuture: loadUpdateLog()))),
      onOpenExport: (c) => Navigator.of(c).push(MaterialPageRoute<void>(
          builder: (_) => HistoryExportView(
                records: ref.read(historyProvider),
                questions: questions,
              ))),
    );
  }
}
