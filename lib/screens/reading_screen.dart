import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'learn_screen.dart';

/// 章ごとの解説読み物（教科書的なまとめページ）の一覧。
class ReadingListScreen extends StatelessWidget {
  const ReadingListScreen({
    super.key,
    required this.readings,
    required this.terms,
    required this.questions,
  });

  final List<ChapterReading> readings;
  final List<Term> terms;
  final List<Question> questions;

  Term? _termById(String termId) {
    for (final t in terms) {
      if (t.termId == termId) return t;
    }
    return null;
  }

  Question? _questionById(String qid) {
    for (final q in questions) {
      if (q.qid == qid) return q;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const EmptyState(message: '解説読み物のデータがまだありません。');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: readings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = readings[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(r.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: Text(r.title)),
                  body: ChapterReadingWidget(
                    title: r.title,
                    sections: [
                      for (final s in r.sections)
                        ReadingSectionView(heading: s.heading, body: s.body),
                    ],
                    relatedTerms: [
                      for (final id in r.relatedTermIds)
                        if (_termById(id) != null)
                          RelatedTermRef(termId: id, label: _termById(id)!.term),
                    ],
                    relatedQuestions: [
                      for (final id in r.relatedQuestionIds)
                        if (_questionById(id) != null)
                          RelatedQuestionRef(
                            questionId: id,
                            label: _questionById(id)!.prompt,
                          ),
                    ],
                    onRelatedTermTap: (termId) {
                      final term = _termById(termId);
                      if (term == null) return;
                      showTermCard(
                        context,
                        term: term.term,
                        headline: term.headline,
                        definition: term.definition,
                        analogy: term.analogy,
                        commonMistake: term.commonMistake,
                      );
                    },
                    onRelatedQuestionTap: (qid) {
                      final question = _questionById(qid);
                      if (question == null) return;
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => Scaffold(
                            appBar: AppBar(title: const Text('関連問題')),
                            body: LearnScreen(
                              questions: [question],
                              terms: terms,
                              sessionSize: 1,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
