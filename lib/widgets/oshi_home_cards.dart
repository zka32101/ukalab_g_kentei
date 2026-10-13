import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/history_store.dart';
import '../data/oshi_recap.dart';
import '../data/progress_store.dart';

/// ホームの「推しの一言」。学習状況(解答履歴・連続学習・試験日)から、責めない一言を出す。
/// タップで別の一言。無料。文言・選び方は ukalab_core。
class OshiMessageCard extends ConsumerWidget {
  const OshiMessageCard({super.key, this.examDate, this.clock = DateTime.now});

  /// 試験日(設定した人だけ。励ましの文脈で軽く触れるだけ)。
  final DateTime? examDate;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = clock();
    final situation = oshiMessageContextFor(
      records: ref.watch(historyProvider),
      progress: ref.watch(progressProvider),
      now: now,
      examDate: examDate,
    );
    return OshiMessageBubble(situation: situation, now: now);
  }
}

/// ホームの「週間ふりかえり」。今週(月曜始まり)にできたことだけを見せる。無料。
/// 解いていない週は、責めずに穏やかな表示になる(core 側)。
class WeeklyRecapSection extends ConsumerWidget {
  const WeeklyRecapSection({
    super.key,
    required this.exam,
    required this.questions,
    this.clock = DateTime.now,
  });

  final ExamConfig exam;
  final List<Question> questions;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(historyProvider);
    return WeeklyRecapCard(
      recap: weeklyRecapFor(records: records, now: clock()),
      topicLabel: topicLabelFor(questions, (id) => exam.subject(id)?.name),
    );
  }
}
