import 'package:app_common_kit/app_common_kit.dart';
import 'package:app_common_kit/hands_free_tts.dart';
import 'package:ukalab_core/daily_goal.dart' show recordDailyAnswer;
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/history_store.dart';
import '../data/progress_store.dart';

/// 「学ぶ」タブ: 短い演習セッション（最小実装。間隔反復・弱点優先は後続）。
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({
    super.key,
    required this.questions,
    required this.terms,
    this.sessionSize = 10,
  });

  final List<Question> questions;
  final List<Term> terms;
  final int sessionSize;

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  late PracticeSession _session = _newSession();
  int? _selected;
  bool _answered = false;

  /// 出題を表示した時刻（回答にかかった時間の計測用）。
  DateTime _shownAt = DateTime.now();

  /// 回答済みの間に画面へ出す問題。
  ///
  /// [PracticeSession.answer] は呼んだ時点で「現在の問題」を次へ進める。画面が
  /// そのまま `_session.current` で描くと、回答した直後に次の問題の解説・選択肢の
  /// 正誤の色が出てしまい、最後の問題では解説を読む前に結果画面へ飛ぶ。
  /// そのため、回答した問題をここに覚えておき、「次へ」を押すまでこの問題で描く。
  Question? _answeredQuestion;

  /// 問題ごとの選択肢の表示順（qid→実際のchoicesインデックスの並び）。
  /// 正解が常に先頭に来てしまわないよう、問題ごとに1回だけシャッフルする。
  final Map<String, List<int>> _choiceOrder = {};

  List<int> _orderFor(Question q) => _choiceOrder.putIfAbsent(
        q.qid,
        () => List.generate(q.choices.length, (i) => i)..shuffle(),
      );

  PracticeSession _newSession() => PracticeSession(
        pool: widget.questions,
        size: widget.sessionSize.clamp(1, widget.questions.length),
        seed: DateTime.now().millisecondsSinceEpoch,
      );

  void _restart() {
    setState(() {
      _session = _newSession();
      _selected = null;
      _answered = false;
      _answeredQuestion = null;
      _choiceOrder.clear();
      _shownAt = DateTime.now();
    });
  }

  Future<void> _select(int i) async {
    if (_answered) return;
    final q = _session.current;
    if (q == null) return;
    setState(() {
      _selected = i;
      _answered = true;
      _answeredQuestion = q;
    });
    _session.answer(i);
    final correct = i == q.answerIndex;
    await ref.read(progressProvider.notifier).recordAnswer(q.qid, correct: correct);
    await recordDailyAnswer(ref);
    await ref.read(historyProvider.notifier).record(
          q,
          correct: correct,
          ms: DateTime.now().difference(_shownAt).inMilliseconds,
        );
    await ref.read(coinProvider.notifier).grant(CoinEvent.newQuestion(q.qid));
    final streakDays = ref.read(progressProvider).streakDays;
    if (streakCoinMilestones.contains(streakDays)) {
      await ref.read(coinProvider.notifier).grant(CoinEvent.streak(streakDays));
    }
  }

  Future<void> _next() async {
    setState(() {
      _selected = null;
      _answered = false;
      _answeredQuestion = null;
      _shownAt = DateTime.now();
    });
    if (_session.current == null) {
      await ref.read(adGateProvider).maybeShowInterstitial(InterstitialTrigger.sessionEnd);
    }
  }

  List<TermReference> get _termRefs => [
        for (final t in widget.terms) TermReference(termId: t.termId, matchText: t.term),
      ];

  Term? _termById(String termId) {
    for (final t in widget.terms) {
      if (t.termId == termId) return t;
    }
    return null;
  }

  void _openTerm(Term term) {
    showTermCard(
      context,
      term: term.term,
      headline: term.headline,
      definition: term.definition,
      analogy: term.analogy,
      commonMistake: term.commonMistake,
      relatedTerms: [
        for (final id in term.relatedTermIds)
          if (_termById(id) != null)
            RelatedTermRef(termId: id, label: _termById(id)!.term),
      ],
      onRelatedTermTap: (nextId) {
        final next = _termById(nextId);
        if (next == null) return;
        Navigator.of(context).pop();
        _openTerm(next);
      },
    );
  }

  void _onTermTap(String termId) {
    final term = _termById(termId);
    if (term != null) _openTerm(term);
  }

  List<Widget> _buildChoices(Question q) {
    final order = _orderFor(q);
    final widgets = <Widget>[];
    for (var pos = 0; pos < order.length; pos++) {
      if (pos > 0) widgets.add(const SizedBox(height: 8));
      final i = order[pos];
      widgets.add(ChoiceTile(
        label: String.fromCharCode(0x41 + pos),
        text: q.choices[i],
        state: !_answered
            ? (_selected == i ? ChoiceState.selected : ChoiceState.idle)
            : (i == q.answerIndex
                ? ChoiceState.correct
                : (i == _selected ? ChoiceState.incorrect : ChoiceState.idle)),
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
    // 回答済みの間は、回答した問題で描く（_answeredQuestion の説明を参照）。
    final q = _answeredQuestion ?? _session.current;
    if (q == null) {
      final adGate = ref.watch(adGateProvider);
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ResultSummary(
                correct: _session.correctCount,
                total: _session.questions.length,
                onRetry: _restart,
              ),
              const SizedBox(height: 16),
              adGate.banner(BannerPlacement.result),
            ],
          ),
        ),
      );
    }

    if (ref.watch(handsFreeProvider).enabled && !_answered) {
      final order = _orderFor(q);
      return HandsFreeChoiceBody(
        qid: q.qid,
        prompt: q.prompt,
        choices: [for (final i in order) q.choices[i]],
        index: _session.index + 1,
        total: _session.questions.length,
        onSelect: (pos) => _select(order[pos]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: BookmarkToggleButton(qid: q.qid),
          ),
          QuestionCard(
            text: q.prompt,
            textWidget: TappableTermText(
              text: q.prompt,
              terms: _termRefs,
              onTermTap: _onTermTap,
            ),
            // 回答済みの間は、_session.index がすでに進んでいるので、1つ戻す。
            index: _session.index + (_answered ? 0 : 1),
            total: _session.questions.length,
            child: Column(
              children: _buildChoices(q),
            ),
          ),
          if (_answered) ...[
            const SizedBox(height: 16),
            ExplanationPanel(
              body: q.explanation,
              bodyWidget: TappableTermText(
                text: q.explanation,
                terms: _termRefs,
                onTermTap: _onTermTap,
              ),
              sourceRef: q.sourceRef,
            ),
            const SizedBox(height: 12),
            QuestionMemoField(key: ValueKey(q.qid), qid: q.qid),
            const SizedBox(height: 16),
            FilledButton(onPressed: _next, child: const Text('次へ')),
          ],
        ],
      ),
    );
  }
}
