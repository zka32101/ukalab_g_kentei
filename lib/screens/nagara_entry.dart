import 'dart:math';

import 'package:app_common_kit/app_common_kit.dart';
import 'package:app_common_kit/hands_free_tts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/daily_goal.dart' show recordDailyAnswer;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/feature_flags.dart';
import '../data/history_store.dart';
import '../data/mistake_notes.dart';
import '../data/progress_store.dart';
import '../data/review_schedule.dart';

/// ながらセッション1回あたりの上限問数（ひと続きで聞きすぎないための休憩の目安）。
const int kNagaraMaxQuestions = 20;

/// ながらセッションの出題元。
enum NagaraSource {
  /// 全分野からランダム。
  all,

  /// 直近に解いた分野(履歴が無ければ全分野)。
  recentSubject,

  /// 間違いノートの、まだ克服していない問題。
  mistakes,
}

/// 出題元から問題を選ぶ(順序はシャッフル済み)。
///
/// [mistakeQids] は [NagaraSource.mistakes] のときの対象。どれも無料の範囲で、
/// 弱点ドリル(プレミアム)の出題ロジックは使わない。
List<Question> buildNagaraPool(
  NagaraSource source, {
  required List<Question> questions,
  required List<ProgressRecord> history,
  Set<String> mistakeQids = const {},
  Random? random,
}) {
  final rnd = random ?? Random();
  // 音声の流れは選択式前提。○×・空欄補充・説明から用語は、フラグに関わらず出さない。
  questions = withoutNewTypes(questions);
  List<Question> pool;
  switch (source) {
    case NagaraSource.all:
      pool = [...questions];
    case NagaraSource.recentSubject:
      final recent = recentSubjectId(history);
      pool = recent == null
          ? [...questions]
          : [for (final q in questions) if (q.subjectId == recent) q];
    case NagaraSource.mistakes:
      pool = [for (final q in questions) if (mistakeQids.contains(q.qid)) q];
  }
  pool.shuffle(rnd);
  return pool;
}

/// 履歴のうち最も新しい解答の分野ID。履歴が空なら null。
String? recentSubjectId(List<ProgressRecord> history) {
  ProgressRecord? latest;
  for (final r in history) {
    if (latest == null || r.at.isAfter(latest.at)) latest = r;
  }
  return latest?.subjectId;
}

/// 画面の読み上げ用に変換する。選択肢の並びは問題ごとにシャッフルし、正解が常に「ア」にならないようにする。
List<NagaraQuestion> toNagaraQuestions(List<Question> qs, {Random? random}) {
  final rnd = random ?? Random();
  return [
    for (final q in withoutNewTypes(qs))
      () {
        final order = List.generate(q.choices.length, (i) => i)..shuffle(rnd);
        return NagaraQuestion(
          id: q.qid,
          prompt: q.prompt,
          choices: [for (final i in order) q.choices[i]],
          correctIndex: order.indexOf(q.answerIndex),
          explanation: q.explanation,
        );
      }(),
  ];
}

/// ホームに足す、ながらセッションの入口(無料)。
class NagaraEntryCard extends StatelessWidget {
  const NagaraEntryCard({
    super.key,
    required this.exam,
    required this.questions,
    required this.terms,
  });

  final ExamConfig exam;
  final List<Question> questions;
  final List<Term> terms;

  @override
  Widget build(BuildContext context) => HomeMenuTile(
        icon: Icons.headphones_outlined,
        title: 'ながらセッション',
        subtitle: '耳で聞きながら、問題が自動で進みます。画面が点いている間だけ動きます。',
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => NagaraStartScreen(exam: exam, questions: questions),
        )),
      );
}

/// 出題元を選ぶ画面。
class NagaraStartScreen extends ConsumerWidget {
  const NagaraStartScreen({
    super.key,
    required this.exam,
    required this.questions,
    this.mistakeStore,
    this.maxQuestions = kNagaraMaxQuestions,
  });

  final ExamConfig exam;
  final List<Question> questions;

  /// テスト用の差し替え。省略時は端末内の間違いノート。
  final MistakeNoteStore? mistakeStore;
  final int maxQuestions;

  void _toast(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  void _start(BuildContext context, List<Question> pool) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NagaraSessionScreen(questions: pool, maxQuestions: maxQuestions),
    ));
  }

  Future<void> _begin(BuildContext context, WidgetRef ref, NagaraSource source) async {
    await ref.read(historyProvider.notifier).ready;
    final history = ref.read(historyProvider);
    var mistakeQids = <String>{};
    if (source == NagaraSource.mistakes) {
      final saved = await (mistakeStore ?? mistakeNoteStore).read();
      final entries = mistakeNoteEngine.update(saved, history);
      mistakeQids = {for (final e in entries) if (!e.overcome) e.qid};
    }
    if (!context.mounted) return;
    final pool = buildNagaraPool(source,
        questions: questions, history: history, mistakeQids: mistakeQids);
    if (pool.isEmpty) {
      _toast(context, source == NagaraSource.mistakes
          ? '復習する問題はいまありません。'
          : '問題データがまだありません。');
      return;
    }
    _start(context, pool);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = recentSubjectId(ref.watch(historyProvider));
    final recentName = recent == null ? null : exam.subject(recent)?.name;
    return Scaffold(
      appBar: AppBar(title: const Text('ながらセッション')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '問題と選択肢を読み上げ、考える時間のあと、答えと解説を読みます。'
            '1回につき最大$maxQuestions問です。バックグラウンドや画面ロック中は止まります。',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.shuffle),
              title: const Text('全体から'),
              subtitle: const Text('全分野からランダムに出します。'),
              onTap: () => _begin(context, ref, NagaraSource.all),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.history),
              title: const Text('最近の分野'),
              subtitle: Text(recentName == null
                  ? 'まだ履歴がないので、全体から出します。'
                  : '直近に解いた「$recentName」から出します。'),
              onTap: () => _begin(context, ref, NagaraSource.recentSubject),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('間違いノートの復習'),
              subtitle: const Text('まだ克服していない問題から出します。'),
              onTap: () => _begin(context, ref, NagaraSource.mistakes),
            ),
          ),
        ],
      ),
    );
  }
}

/// ながらセッション本体。タップで答えた解答(正解・誤答とも)は通常の解答と同じ経路(進捗・日次・履歴・コイン)に記録する。
///
/// 間違いノートは履歴から取り込むので、履歴に載せれば自動で反映される。
/// 記録は kit の `onAnswered` に一本化する(`onWrongAnswer` は使わず二重記録を避ける)。
/// 未回答とスキップは `onAnswered` が呼ばれないので記録しない。
class NagaraSessionScreen extends ConsumerStatefulWidget {
  const NagaraSessionScreen({
    super.key,
    required this.questions,
    this.maxQuestions = kNagaraMaxQuestions,
  });

  final List<Question> questions;
  final int maxQuestions;

  @override
  ConsumerState<NagaraSessionScreen> createState() => _NagaraSessionScreenState();
}

class _NagaraSessionScreenState extends ConsumerState<NagaraSessionScreen> {
  late final List<NagaraQuestion> _nagara = toNagaraQuestions(widget.questions);
  late final Map<String, Question> _byQid = {for (final q in widget.questions) q.qid: q};

  Future<void> _onAnswered(NagaraQuestion nq, int chosen, bool correct) async {
    final q = _byQid[nq.id];
    if (q == null) return;
    // await をまたいで ref を触らないよう、先に取っておく。
    final progress = ref.read(progressProvider.notifier);
    final history = ref.read(historyProvider.notifier);
    final coins = ref.read(coinProvider.notifier);
    try {
      final daily = recordDailyAnswer(ref);
      await progress.recordAnswer(q.qid, correct: correct);
      final at = DateTime.now();
      await applyReviewResult(q.qid, correct: correct, at: at);
      await history.record(q, correct: correct, at: at);
      await coins.grant(CoinEvent.newQuestion(q.qid));
      await daily;
    } catch (_) {
      // 記録に失敗してもセッションは止めない。
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ながらセッション')),
        body: SafeArea(
          child: NagaraSessionView(
            questions: _nagara,
            maxQuestions: widget.maxQuestions,
            onAnswered: _onAnswered,
            onClose: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
}
