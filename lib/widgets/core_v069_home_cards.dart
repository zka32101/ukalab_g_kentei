import 'package:app_common_kit/app_common_kit.dart' show EntitlementState, entitlementStateProvider;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/history_store.dart';
import '../data/mock_exam_quota.dart';
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

const _freeReviewPerDay = 10;

class _TodayReviewSectionState extends ConsumerState<TodayReviewSection> {
  int _dueCount = 0;
  int _generation = 0;

  /// 無料版の1日の復習の上限に達していて、まだ期限の来た復習が残っている。
  bool _limitReached = false;

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
      var due = reviewSchedulerEngine.dueCount(items, widget.clock());
      var limitReached = false;
      // 無料版は1日の復習が決まった数まで(プレミアムは無制限)。
      final isPremium = (ref.read(entitlementStateProvider).valueOrNull ?? EntitlementState.free).hasPremium;
      if (!isPremium) {
        final remaining = (await todayReviewQuota(isPremium: false)).remaining ?? due;
        if (due > remaining) due = remaining;
        limitReached = remaining <= 0 && reviewSchedulerEngine.dueCount(items, widget.clock()) > 0;
      }
      if (!mounted || gen != _generation) return;
      setState(() {
        _dueCount = due;
        _limitReached = limitReached;
      });
    } catch (_) {
      // 読めなくても件数 0(おやすみ表示)で動く。
    }
  }

  @override
  Widget build(BuildContext context) {
    // 解答が増えたら(復習・通常の演習どちらでも)数え直す。
    ref.listen(historyProvider, (_, __) => _refresh());
    if (_limitReached) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('今日の復習', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text(
                '無料版の今日の復習($_freeReviewPerDay問)は終わりました。\n'
                '続きは明日。プレミアムなら、続けて復習できます(間違いノートは、いつでも開けます)。',
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => openMistakeNote(
                  context,
                  exam: widget.exam,
                  questions: widget.questions,
                  terms: widget.terms,
                ),
                child: const Text('間違いノートを開く'),
              ),
            ],
          ),
        ),
      );
    }
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

/// ホーム「②記録」に置く、推しの成長演出の見張り役。吹き出し(OshiGrowthBubble)はホームに出さない
/// (常時表示は「推しの一言」だけ)。節目(10/50/100/300/1000 問・7/30/100 日)に届いたときの祝福(一度だけ)を担う。
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
    // CI の Flutter 3.35 には valuesOf が無いため of を使う(新しい版では非推奨)。
    // ignore: deprecated_member_use
    final visible = TickerMode.of(context);
    if (!visible || (route != null && !route.isCurrent)) return;
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
    // 表示はしないが、解答履歴の変化を購読して節目の判定を続ける(祝福の発火経路を従来どおり保つ)。
    ref.watch(historyProvider);
    ref.watch(progressProvider);
    return const SizedBox.shrink();
  }
}
