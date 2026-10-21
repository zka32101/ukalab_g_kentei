import 'dart:async';

import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_core/learning.dart';

import '../data/feature_flags.dart';
import '../widgets/centered_scroll.dart';

/// 「145問ペース走」画面（型④の直前版、決定76）。
///
/// 本番「100分で約145問」のペース感覚を、短縮版（20問×14分）で体感する。
/// タイマー・旗（見直し候補）・ペース表示に加え、選んだ答えの正誤を数えて最後に出す。
class PaceRunScreen extends StatefulWidget {
  const PaceRunScreen({super.key, required this.questions});

  final List<Question> questions;

  static const _config = PaceRunConfig(questionCount: 20, timeLimitSec: 14 * 60);

  @override
  State<PaceRunScreen> createState() => _PaceRunScreenState();
}

class _PaceRunScreenState extends State<PaceRunScreen> {
  static const _runner = PaceRunner(PaceRunScreen._config);

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _started = false;
  bool _finished = false;
  bool _timedOut = false;
  int _index = 0;
  final Set<String> _flagged = {};
  int _correct = 0;
  List<Question> _picked = const [];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    // 選択式前提の画面。新タイプはフラグに関わらず出さない。
    final picked = withoutNewTypes(widget.questions)..shuffle();
    final count = PaceRunScreen._config.questionCount.clamp(1, widget.questions.length);
    setState(() {
      _picked = picked.take(count).toList();
      _flagged.clear();
      _correct = 0;
      _index = 0;
      _elapsed = Duration.zero;
      _started = true;
      _finished = false;
      _timedOut = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final next = _elapsed + const Duration(seconds: 1);
    if (next.inSeconds >= PaceRunScreen._config.timeLimitSec) {
      _finish(timedOut: true);
      return;
    }
    setState(() => _elapsed = next);
  }

  void _toggleFlag(String qid) {
    setState(() {
      if (!_flagged.remove(qid)) _flagged.add(qid);
    });
  }

  void _next(int chosen) {
    if (chosen == _picked[_index].answerIndex) _correct++;
    if (_index + 1 < _picked.length) {
      setState(() => _index++);
    } else {
      _finish(timedOut: false);
    }
  }

  void _finish({required bool timedOut}) {
    _timer?.cancel();
    setState(() {
      _finished = true;
      _timedOut = timedOut;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return const EmptyState(message: '問題データがまだありません。');
    }
    if (!_started) return _buildIntro(context);
    if (_finished) return _buildResult(context);
    return _buildRun(context);
  }

  Widget _buildIntro(BuildContext context) {
    final config = PaceRunScreen._config;
    return CenteredScroll(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('145問ペース走', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '本番は100分で約145問（1問あたり約41秒）。'
            'その感覚を${config.questionCount}問・${config.timeLimitSec ~/ 60}分の短縮版で体感します。'
            '答えの正誤は最後にまとめて採点します。ペースと見直し候補（旗）も練習できます。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _start, child: const Text('ペース走を始める')),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context) {
    return CenteredScroll(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _timedOut ? '時間切れ' : '最後まで解き終えました',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text('解答数: ${_index + (_timedOut ? 0 : 1)} / ${_picked.length}問'),
          Text('正解数: $_correct / ${_picked.length}問'),
          Text('見直し候補（旗）: ${_flagged.length}問'),
          const SizedBox(height: 24),
          FilledButton(onPressed: _start, child: const Text('もう一度')),
        ],
      ),
    );
  }

  Widget _buildRun(BuildContext context) {
    final q = _picked[_index];
    final flagged = _flagged.contains(q.qid);
    final status = _runner.statusAt(answeredCount: _index, elapsed: _elapsed);
    final remaining = PaceRunScreen._config.timeLimitSec - _elapsed.inSeconds;
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // 文字が大きいときは残り時間を折り返し、旗のボタンを押し出さない。
              Expanded(
                child: Text('残り $minutes:$seconds', style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(
                icon: Icon(flagged ? Icons.flag : Icons.flag_outlined),
                color: flagged ? Theme.of(context).colorScheme.error : null,
                onPressed: () => _toggleFlag(q.qid),
                tooltip: '見直し候補にする',
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 1問も解いていない間は、ペースを見積もれない（0問÷経過秒＝0 になり誤警告が出る）。
          Text(
            _index == 0
                ? 'ペースは、1問解いてから表示します'
                : status.onTrack
                    ? 'このペースなら時間内に解き切れそうです（${status.aheadBy >= 0 ? '+' : ''}${status.aheadBy}問）'
                    : 'このペースだと時間切れで残り'
                        '${(PaceRunScreen._config.questionCount - status.projectedTotal).clamp(0, PaceRunScreen._config.questionCount)}問'
                        '解けないかもしれません',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _index > 0 && !status.onTrack ? Theme.of(context).colorScheme.error : null,
                ),
          ),
          const SizedBox(height: 16),
          QuestionCard(
            text: q.prompt,
            index: _index + 1,
            total: _picked.length,
            child: Column(
              children: [
                for (var i = 0; i < q.choices.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  ChoiceTile(
                    label: String.fromCharCode(0x41 + i),
                    text: q.choices[i],
                    state: ChoiceState.idle,
                    onTap: () => _next(i),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
