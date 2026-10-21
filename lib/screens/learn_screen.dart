import 'package:app_common_kit/app_common_kit.dart';
import 'package:app_common_kit/hands_free_tts.dart';
import 'package:ukalab_core/answer_feedback.dart' show AnswerFeedbackPanel;
import 'package:ukalab_core/daily_goal.dart' show recordDailyAnswer;
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_core/learning.dart';

import '../data/feature_flags.dart';
import '../data/history_store.dart';
import '../data/progress_store.dart';
import '../data/review_schedule.dart';
import '../widgets/learn_tools_section.dart';

/// 「学ぶ」タブ: 短い演習セッション（最小実装。間隔反復・弱点優先は後続）。
class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({
    super.key,
    required this.questions,
    required this.terms,
    this.sessionSize = 10,
    this.newTypesEnabled = kNewQuestionTypesEnabled,
    this.exam,
    this.chapterReadings = const [],
    this.aiNewsItems = const [],
  });

  final List<Question> questions;
  final List<Term> terms;
  final int sessionSize;

  /// ○×・空欄補充・説明から用語を出題に含めるか（既定は [kNewQuestionTypesEnabled]）。
  /// false のときは [questions] に含まれていても出さない（二重の防御）。
  final bool newTypesEnabled;

  /// 渡すと、画面の下に「道具」（間違いノート・メモ・用語集・読み物・用語マップの入口）を出す。
  /// 「学ぶ」タブ本体だけが渡す（弱点ドリルなど、演習だけを開く使い方では渡さない）。
  final ExamConfig? exam;
  final List<ChapterReading> chapterReadings;
  final List<AiNewsItem> aiNewsItems;

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

  late final List<Question> _pool =
      selectableQuestions(widget.questions, newTypesEnabled: widget.newTypesEnabled);

  PracticeSession _newSession() => PracticeSession(
        pool: _pool,
        size: widget.sessionSize.clamp(1, _pool.length),
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
    await _recordResult(q, correct: i == q.answerIndex);
  }

  /// 新タイプ（○×・空欄補充・説明から用語）の解答。core の画面の結果を
  /// [PracticeSession] に渡し、履歴・進捗・復習予定にも記録する。
  Future<void> _answerNewType(Question q, QuestionViewResult r) async {
    if (_answered || _session.current?.qid != q.qid) return;
    setState(() {
      _answered = true;
      _answeredQuestion = q;
    });
    switch (q.type) {
      case QuestionType.trueFalse:
        _session.answerTrueFalse(r.boolAnswer!);
      case QuestionType.cloze:
        _session.answerCloze(r.blankAnswers!);
      case QuestionType.reverseLookup:
        _session.answerReverseLookup(r.text!);
      case QuestionType.choice:
      case QuestionType.journal:
      case QuestionType.worksheet:
      case QuestionType.ledger:
        return;
    }
    await _recordResult(q, correct: r.correct);
  }

  /// 自由入力の打ち間違いを本人が「合っていた」と申告したとき。直前の不正解の記録を正解に直す。
  Future<void> _selfReported(Question q) async {
    _session.markLastSelfReportedCorrect();
    await ref.read(historyProvider.notifier).markLatestCorrect(q.qid);
    await ref.read(progressProvider.notifier).recordAnswer(q.qid, correct: true);
    await applyReviewResult(q.qid, correct: true, at: DateTime.now());
  }

  Future<void> _recordResult(Question q, {required bool correct}) async {
    await ref.read(progressProvider.notifier).recordAnswer(q.qid, correct: correct);
    await recordDailyAnswer(ref);
    // 履歴と同じ時刻で復習予定に反映する(先に反映し、ホームが履歴の更新で読み直すときに間に合わせる)。
    final at = DateTime.now();
    await applyReviewResult(q.qid, correct: correct, at: at);
    await ref.read(historyProvider.notifier).record(
          q,
          correct: correct,
          ms: at.difference(_shownAt).inMilliseconds,
          at: at,
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

  /// 「道具」の入口。[LearnScreen.exam] を渡されたときだけ。
  Widget _tools() {
    final exam = widget.exam;
    if (exam == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: LearnToolsSection(
        exam: exam,
        questions: widget.questions,
        terms: widget.terms,
        chapterReadings: widget.chapterReadings,
        aiNewsItems: widget.aiNewsItems,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pool.isEmpty) {
      if (widget.exam == null) {
        return const EmptyState(message: '問題データがまだありません。');
      }
      return SingleChildScrollView(
        child: Column(children: [
          const EmptyState(message: '問題データがまだありません。'),
          _tools(),
        ]),
      );
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
              _tools(),
            ],
          ),
        ),
      );
    }

    // ハンズフリー表示は選択式前提。新タイプは通常の画面（core の画面）で出す。
    if (ref.watch(handsFreeProvider).enabled && !_answered && !isNewQuestionType(q)) {
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

    if (isNewQuestionType(q)) return _buildNewType(q);

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
            // 不正解のときだけ表示される（原因ラベル・違いの比較・対策）。
            AnswerFeedbackPanel(
              key: ValueKey('feedback-${q.qid}'),
              question: q,
              selectedIndex: _selected,
              terms: widget.terms,
              includeCalculation: false,
              onCause: (c) => ref.read(historyProvider.notifier).setCause(q.qid, c),
            ),
            const SizedBox(height: 12),
            QuestionMemoField(key: ValueKey(q.qid), qid: q.qid),
            const SizedBox(height: 16),
            FilledButton(onPressed: _next, child: const Text('次へ')),
          ],
          _tools(),
        ],
      ),
    );
  }

  /// 新タイプの問題。出題・採点・解説・間違えた理由・「次へ」は core の画面が受け持つ。
  Widget _buildNewType(Question q) {
    final index = _session.index + (_answered ? 0 : 1);
    final total = _session.questions.length;
    final Widget view = switch (q.type) {
      QuestionType.trueFalse => TrueFalseQuestionView(
          key: ValueKey('tf-${q.qid}'),
          question: q,
          terms: widget.terms,
          index: index,
          total: total,
          onAnswered: (r) => _answerNewType(q, r),
          onCause: (c) => ref.read(historyProvider.notifier).setCause(q.qid, c),
          onNext: _next,
        ),
      QuestionType.cloze => ClozeQuestionView(
          key: ValueKey('cloze-${q.qid}'),
          question: q,
          terms: widget.terms,
          index: index,
          total: total,
          onAnswered: (r) => _answerNewType(q, r),
          onSelfReported: () => _selfReported(q),
          onCause: (c) => ref.read(historyProvider.notifier).setCause(q.qid, c),
          onNext: _next,
        ),
      _ => ReverseLookupQuestionView(
          key: ValueKey('rev-${q.qid}'),
          question: q,
          terms: widget.terms,
          index: index,
          total: total,
          onAnswered: (r) => _answerNewType(q, r),
          onSelfReported: () => _selfReported(q),
          onCause: (c) => ref.read(historyProvider.notifier).setCause(q.qid, c),
          onNext: _next,
        ),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: BookmarkToggleButton(qid: q.qid),
          ),
          view,
          if (_answered) ...[
            const SizedBox(height: 12),
            QuestionMemoField(key: ValueKey(q.qid), qid: q.qid),
          ],
          _tools(),
        ],
      ),
    );
  }
}
