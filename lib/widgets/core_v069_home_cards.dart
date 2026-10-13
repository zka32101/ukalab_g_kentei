import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/history_store.dart';
import '../data/oshi_growth.dart';
import '../data/progress_store.dart';
import '../data/review_schedule.dart';
import '../screens/mistake_note_screen.dart';

/// ホーム「①今日やること」の「今日の復習」。間違いノートから復習予定を同期して期限分を数える。
/// 「やってみる」は既存の間違いノート画面を開く(出題画面は新しく作らない)。無料。
class TodayReviewSection extends ConsumerStatefulWidget {
  const TodayReviewSection({
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
  ConsumerState<TodayReviewSection> createState() => _TodayReviewSectionState();
}

class _TodayReviewSectionState extends ConsumerState<TodayReviewSection> {
  int _dueCount = 0;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final gen = ++_generation;
    try {
      // 履歴の読み込み完了を待つ(読み込み前の空の履歴で同期しない)。
      await ref.read(historyProvider.notifier).ready;
      if (!mounted) return;
      final items = await syncReviewSchedule(
        records: ref.read(historyProvider),
        knownQids: {for (final q in widget.questions) q.qid},
      );
      if (!mounted || gen != _generation) return;
      setState(() => _dueCount = reviewSchedulerEngine.dueCount(items, widget.clock()));
    } catch (_) {
      // 読めなくても件数 0(おやすみ表示)で動く。
    }
  }

  @override
  Widget build(BuildContext context) {
    // 解答が増えたら(復習・通常の演習どちらでも)数え直す。
    ref.listen(historyProvider, (_, __) => _refresh());
    return TodayReviewCard(
      dueCount: _dueCount,
      onStart: () => openMistakeNote(
        context,
        exam: widget.exam,
        questions: widget.questions,
        terms: widget.terms,
      ),
    );
  }
}

/// ホーム「②記録」の模擬試験の結果分析。解答履歴(科目ごとの正誤)から作る。
/// 履歴がまだ無いときは何も出さない。無料。
class MockExamAnalysisSection extends ConsumerWidget {
  const MockExamAnalysisSection({super.key, required this.exam});

  final ExamConfig exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(historyProvider);
    if (records.isEmpty) return const SizedBox.shrink();
    final analysis = const MockExamAnalysisEngine().analyze([
      for (final r in records) MockExamAnswer(topicId: r.subjectId, correct: r.correct),
    ]);
    return MockExamAnalysisCard(
      analysis: analysis,
      topicLabel: (id) => exam.subject(id)?.name ?? id,
    );
  }
}

/// ホーム「②記録」の推しの成長演出。累計の回答数・学習日数に応じた一言(タップで別の一言)と、
/// 節目(10/50/100/300/1000 問・7/30/100 日)に届いたときの祝福(一度だけ)。
///
/// 祝福は、この画面が見えていて一番上にあるときだけ出す(学習中の画面に割り込まない)。
/// 保存に失敗したら記録されず、次回また祝える。無料。
class OshiGrowthSection extends ConsumerStatefulWidget {
  const OshiGrowthSection({super.key, this.store});

  /// テスト用の差し替え。省略時は端末内の保存先。
  final OshiGrowthStore? store;

  @override
  ConsumerState<OshiGrowthSection> createState() => _OshiGrowthSectionState();
}

class _OshiGrowthSectionState extends ConsumerState<OshiGrowthSection> {
  OshiGrowthService? _service;
  bool _checking = false;

  OshiGrowthProgress _progress() => oshiGrowthProgressFor(
        records: ref.read(historyProvider),
        progress: ref.read(progressProvider),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // タブが再び見えたときなど。
    _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    final route = ModalRoute.of(context);
    if (!TickerMode.valuesOf(context).enabled || (route != null && !route.isCurrent)) return;
    _checking = true;
    try {
      await ref.read(historyProvider.notifier).ready;
      if (!mounted) return;
      final service = _service ??= OshiGrowthService(store: widget.store ?? oshiGrowthStore);
      await service.load();
      if (!mounted) return;
      final milestone = await service.checkHeadline(_progress());
      if (milestone != null && mounted) {
        await showOshiGrowthDialog(context, milestone: milestone);
      }
    } catch (_) {
      // 祝福は付加機能。失敗しても画面は止めない(未記録なら次回また祝える)。
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(historyProvider, (_, __) => _check());
    final progress = oshiGrowthProgressFor(
      records: ref.watch(historyProvider),
      progress: ref.watch(progressProvider),
    );
    return OshiGrowthBubble(progress: progress);
  }
}
