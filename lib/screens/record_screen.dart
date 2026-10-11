import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/achievements.dart' show AchievementsView, dailyGoalAchievementCategoryLabels;
import 'package:ukalab_core/ukalab_core.dart';

import '../data/progress_store.dart';
import '../data/subject_progress.dart';

/// 「記録」タブ: 解いた問題数・正答率・連続学習日数・科目別の正答率。
/// 間隔反復・苦手分析・平均点・偏差値は後続（決定30・50）。
class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key, this.exam, this.questions = const []});

  final ExamConfig? exam;
  final List<Question> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    if (progress.distinctAnswered == 0) {
      return const EmptyState(
        icon: Icons.insights_outlined,
        message: '学習の記録はこれから。演習を進めると、ここに成績が表示されます。',
      );
    }
    final theme = Theme.of(context);
    final answered = progress.distinctAnswered;
    final correct = progress.correctCount;
    final rate = (correct * 100 / answered).round();
    final subjects = computeSubjectProgress(questions, progress.answeredQidToCorrect)
      ..sort((a, b) => a.accuracy.compareTo(b.accuracy));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('学習の記録', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _Stat(label: '解いた問題', value: '$answered問')),
            const SizedBox(width: 12),
            Expanded(child: _Stat(label: '正答率', value: '$rate%')),
            const SizedBox(width: 12),
            Expanded(child: _Stat(label: '連続学習', value: '${progress.streakDays}日')),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.emoji_events_outlined),
          title: const Text('実績'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const AchievementsView(categoryLabels: dailyGoalAchievementCategoryLabels),
            ),
          ),
        ),
        Text(
          progress.mockPassedEver ? '模擬試験: 目安の正答率を超えたことがあります' : '模擬試験: まだ目安の正答率を超えていません',
          style: theme.textTheme.bodyMedium,
        ),
        if (subjects.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('科目別の正答率（低い順）', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final s in subjects)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(exam?.subject(s.subjectId)?.name ?? s.subjectId)),
                      Text('${(s.accuracy * 100).round()}%'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: s.accuracy, minHeight: 8),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Text(value, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
