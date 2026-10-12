import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_core/ui.dart';

import '../data/progress_store.dart';
import '../data/term_mastery.dart';

/// 系譜図（タイムライン）の時代区分。「ブーム・冬の時代・深層学習・生成AI」
/// （決定41）の順。区切りは学習用の目安で、厳密な年代ではない。
const termMapEraOrder = {
  'boom1': '第1次AIブーム',
  'winter1': '第1次AIの冬',
  'boom2': '第2次AIブーム',
  'winter2': '第2次AIの冬',
  'deep_learning': '深層学習の時代',
  'generative_ai': '生成AIの時代',
};

/// 「用語マップ・AI系譜図」画面（決定41、画期的な機能9）。
/// 関連用語でつながる地図と、AIの歴史のタイムラインを1画面で見せる。
/// タップで用語カードをボトムシートで開く（用語集画面と同じ動線）。
class TermMapScreen extends ConsumerWidget {
  const TermMapScreen({super.key, required this.terms});

  final List<Term> terms;

  Term? _termById(String termId) {
    for (final t in terms) {
      if (t.termId == termId) return t;
    }
    return null;
  }

  void _openTerm(BuildContext context, Term term) {
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
        _openTerm(context, next);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (terms.isEmpty) {
      return const EmptyState(message: '用語データがまだありません。');
    }
    final answered = ref.watch(progressProvider).answeredQidToCorrect;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: TermMapWidget(
        nodes: [
          for (final t in terms)
            TermMapNodeSpec(
              termId: t.termId,
              label: t.term,
              era: t.era,
              relatedTermIds: t.relatedTermIds,
              mastery: termMasteryOf(t, answered),
            ),
        ],
        eraOrder: termMapEraOrder,
        onNodeTap: (termId) {
          final term = _termById(termId);
          if (term != null) _openTerm(context, term);
        },
      ),
    );
  }
}
