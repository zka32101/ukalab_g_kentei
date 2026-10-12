import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_core/ui.dart';

/// 用語マップ・AI系譜図（決定41）向け。用語に関連する問題
/// （[Term.relatedQuestionIds]）の正答率から習得度を判定する。
///
/// 1問も解いていなければ [TermMastery.none]。正答率80%以上は
/// [TermMastery.mastered]、50%未満は [TermMastery.weak]、それ以外は
/// 学習中として [TermMastery.none]。
TermMastery termMasteryOf(Term term, Map<String, bool> answeredQidToCorrect) {
  final answered = [
    for (final qid in term.relatedQuestionIds)
      if (answeredQidToCorrect[qid] != null) answeredQidToCorrect[qid]!,
  ];
  if (answered.isEmpty) return TermMastery.none;
  final accuracy = answered.where((c) => c).length / answered.length;
  if (accuracy >= 0.8) return TermMastery.mastered;
  if (accuracy < 0.5) return TermMastery.weak;
  return TermMastery.none;
}
