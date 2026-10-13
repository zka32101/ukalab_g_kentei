import 'dart:async';

import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/mock_exam_history.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/progress_store.dart';
import '../widgets/oshi_card.dart';

/// 「模擬」タブ: 本試験相当の採点（合格ラインの目安は非公開のため70%を目安と明記）。
///
/// 出題は科目別の出題数配分(ExamConfig.levels.subjectQuestionCounts)どおりに
/// 科目ごと抽出する。科目の問題が不足する分はそのまま不足する。
/// 実施でコイン+10、合格で+50(資格ごとに最初の1回のみ)が付与される
/// （決定67〜77）。合格すると、習得度と合わせて「準備完了」の判定も行う。
class MockExamScreen extends ConsumerStatefulWidget {
  const MockExamScreen({
    super.key,
    required this.exam,
    required this.questions,
    this.now = DateTime.now,
  });

  final ExamConfig exam;
  final List<Question> questions;

  /// 現在時刻（テストで差し替える）。
  final DateTime Function() now;

  @override
  ConsumerState<MockExamScreen> createState() => _MockExamScreenState();
}

/// 全国集計(決定32)の examVersion。出題配分(subjectQuestionCounts)を変えたら
/// 上げる（配分が違う回を同じ集計に混ぜないため）。
const _examStatsVersion = 'v1';

class _MockExamScreenState extends ConsumerState<MockExamScreen> {
  bool _started = false;
  int _index = 0;
  final Map<String, int?> _answers = {};
  late List<Question> _picked;
  MockExamResult? _result;
  ExamStatsSummary? _statsSummary;

  /// 制限時間の締切（標準の模擬のみ。カスタムは制限なし）。開始時刻との差で
  /// 計算するので、バックグラウンドに回っても時間は止まらない。
  DateTime? _deadline;
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  /// 問題ごとの選択肢の表示順（qid→実際のchoicesインデックスの並び）。
  /// 正解が常に先頭に来てしまわないよう、問題ごとに1回だけシャッフルする。
  final Map<String, List<int>> _choiceOrder = {};

  List<int> _orderFor(Question q) => _choiceOrder.putIfAbsent(
        q.qid,
        () => List.generate(q.choices.length, (i) => i)..shuffle(),
      );

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTimer(int? limitSec) {
    _ticker?.cancel();
    if (limitSec == null || limitSec <= 0) {
      _deadline = null;
      return;
    }
    _deadline = widget.now().add(Duration(seconds: limitSec));
    _remaining = Duration(seconds: limitSec);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final deadline = _deadline;
    if (deadline == null || _result != null) return;
    final left = deadline.difference(widget.now());
    if (left <= Duration.zero) {
      _ticker?.cancel();
      setState(() => _remaining = Duration.zero);
      _finish();
    } else {
      setState(() => _remaining = left);
    }
  }

  String _remainingText() {
    final sec = _remaining.inSeconds;
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '残り $m:$s';
  }

  bool _isPremium(WidgetRef ref) => canUsePremiumFeature(
        PremiumFeature.mockExamHistory,
        isPremium: (ref.read(entitlementStateProvider).valueOrNull ?? EntitlementState.free)
            .hasPremium,
      );

  void _start() {
    final level = widget.exam.levels.first;
    setState(() {
      _picked = pickMockExamQuestions(
        pool: widget.questions,
        level: level,
        seed: DateTime.now().millisecondsSinceEpoch,
      )..shuffle();
      _answers.clear();
      _choiceOrder.clear();
      _index = 0;
      _started = true;
      _result = null;
      _statsSummary = null;
    });
    _startTimer(level.timeLimitSec);
  }

  void _startCustom(List<String> subjectIds, int count) {
    setState(() {
      _picked = pickCustomMockExamQuestions(
        pool: widget.questions,
        subjectIds: subjectIds,
        count: count,
        seed: DateTime.now().millisecondsSinceEpoch,
      )..shuffle();
      _answers.clear();
      _choiceOrder.clear();
      _index = 0;
      _started = true;
      _result = null;
      _statsSummary = null;
    });
    _startTimer(null);
  }

  Future<void> _openCustomSetup() async {
    final setup = await Navigator.of(context).push<CustomMockExamSetup>(
      MaterialPageRoute(
        builder: (_) => CustomMockExamSetupScreen(subjects: widget.exam.subjects),
      ),
    );
    if (setup != null) _startCustom(setup.subjectIds, setup.count);
  }

  void _select(int i) {
    setState(() => _answers[_picked[_index].qid] = i);
  }

  Future<void> _finish() async {
    if (_result != null) return;
    _ticker?.cancel();
    final rule = widget.exam.levels.first.passRule;
    final result = scoreMockExam(questions: _picked, answers: _answers, rule: rule);
    setState(() => _result = result);

    await ref.read(progressProvider.notifier).touchStudyDay();
    await ref.read(coinProvider.notifier).grant(CoinEvent.mockDone());
    final streakDays = ref.read(progressProvider).streakDays;
    if (streakCoinMilestones.contains(streakDays)) {
      await ref.read(coinProvider.notifier).grant(CoinEvent.streak(streakDays));
    }
    await ref.read(adGateProvider).maybeShowInterstitial(InterstitialTrigger.mockExamResult);

    final stats = ref.read(examStatsServiceProvider);
    final submission = ExamStatsSubmission(
      certId: widget.exam.examId,
      examVersion: _examStatsVersion,
      score: result.total.score,
      totalQuestions: result.total.max,
    );
    await stats.submitResult(submission);
    final summary = await stats.fetchSummary(
      certId: widget.exam.examId,
      examVersion: _examStatsVersion,
    );
    if (mounted) setState(() => _statsSummary = summary);

    if (_isPremium(ref)) {
      await ref.read(mockExamHistoryProvider.notifier).record(result);
    }

    if (!result.passed) return;
    await ref.read(coinProvider.notifier).grant(CoinEvent.mockPass(widget.exam.examId));
    await ref.read(progressProvider.notifier).recordMockResult(passed: true);

    final progress = ref.read(progressProvider);
    final mastery = masteryInputFor(
      distinctAnswered: progress.distinctAnswered,
      totalQuestions: widget.questions.length,
      correct: progress.correctCount,
    );
    if (ReadinessRule.standard.isReady(mastery: mastery, mockPassed: progress.mockPassedEver)) {
      await ref.read(outfitProvider.notifier).markReady(UkalabCert.gKentei);
    }
  }

  void _next() {
    if (_index + 1 < _picked.length) {
      setState(() => _index++);
    } else {
      _finish();
    }
  }

  List<Widget> _buildChoices(Question q, int? selected) {
    final order = _orderFor(q);
    final widgets = <Widget>[];
    for (var pos = 0; pos < order.length; pos++) {
      if (pos > 0) widgets.add(const SizedBox(height: 8));
      final i = order[pos];
      widgets.add(ChoiceTile(
        label: String.fromCharCode(0x41 + pos),
        text: q.choices[i],
        state: selected == i ? ChoiceState.selected : ChoiceState.idle,
        onTap: () => _select(i),
      ));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const EmptyState(message: '問題データがまだありません。');
    }
    final level = widget.exam.levels.first;

    if (!_started) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('模擬試験', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '本試験は${level.questionCount}問・${(level.timeLimitSec ?? 0) ~/ 60}分。'
                '合格基準は非公開のため、正答率70%を目安に表示します。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _start, child: const Text('模擬試験を始める')),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  if (!_isPremium(ref)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('カスタム模擬試験はプレミアムの機能です。設定から購入できます。')),
                    );
                    return;
                  }
                  _openCustomSetup();
                },
                child: const Text('カスタム模擬試験'),
              ),
            ],
          ),
        ),
      );
    }

    final result = _result;
    if (result != null) {
      final adGate = ref.watch(adGateProvider);
      final history = _isPremium(ref) ? ref.watch(mockExamHistoryProvider) : const <MockExamHistoryEntry>[];
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ResultSummary(
                correct: result.total.score,
                total: result.total.max,
                passRatio: level.passRule.totalPct / 100,
                onRetry: _start,
              ),
              const SizedBox(height: 16),
              StatsCompareWidget(summary: _statsSummary, myScore: result.total.score),
              if (history.length > 1) ...[
                const SizedBox(height: 16),
                Text('成長グラフ', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                MockExamTrendChart(
                  points: [
                    for (final h in history) MockExamTrendPoint(pct: h.pct, passed: h.passed),
                  ],
                  passPct: level.passRule.totalPct,
                ),
              ],
              const SizedBox(height: 16),
              adGate.banner(BannerPlacement.result),
            ],
          ),
        ),
      );
    }

    final q = _picked[_index];
    final selected = _answers[q.qid];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_deadline != null) ...[
            Text(
              _remainingText(),
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
          ],
          QuestionCard(
            text: q.prompt,
            index: _index + 1,
            total: _picked.length,
            child: Column(
              children: _buildChoices(q, selected),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: selected == null ? null : _next,
            child: Text(_index + 1 < _picked.length ? '次へ' : '結果を見る'),
          ),
        ],
      ),
    );
  }
}
