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
