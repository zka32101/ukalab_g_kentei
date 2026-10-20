import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../data/exam_repository.dart';
import '../screens/mistake_note_screen.dart';
import '../screens/reading_screen.dart';
import '../screens/term_map_screen.dart';
import '../screens/terms_screen.dart';

/// 「学ぶ」タブの「道具」。間違いノート・メモ（しおり）・用語集・読み物・用語マップ・AI動向への入口。
/// 以前はホームの「今日やること」（間違いノート）と「道具」にあったもの。
/// 見出し名・並びは ukalab_it_passport / ukalab_infosecmanage の「学ぶ」と同じ。
class LearnToolsSection extends ConsumerWidget {
  const LearnToolsSection({
    super.key,
    required this.exam,
    required this.questions,
    required this.terms,
    required this.chapterReadings,
    this.aiNewsItems = const [],
  });

  final ExamConfig exam;
  final List<Question> questions;
  final List<Term> terms;
  final List<ChapterReading> chapterReadings;
  final List<AiNewsItem> aiNewsItems;

  /// 一覧から開く問題の詳細。選択肢の記号は演習（A・B・C…）に合わせる。
  Widget _detailBuilder(BuildContext context, Question q) => QuestionDetailScreen(
        question: q,
        choiceLabels: const ['A', 'B', 'C', 'D', 'E', 'F'],
      );

  void _push(BuildContext context, String title, Widget body) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (context) => Scaffold(appBar: AppBar(title: Text(title)), body: body),
      ));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termReferences =
        ref.watch(examDataProvider).valueOrNull?.termReferences ?? const [];
    return HomeSection(
      title: '道具',
      subtitle: '調べる・見返す',
      leading: const Icon(Icons.handyman_outlined),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (aiNewsItems.isNotEmpty)
              AiNewsCard(
                items: [
                  for (final n in aiNewsItems)
                    AiNewsItemSpec(
                      summary: n.summary,
                      sourceUrl: n.sourceUrl,
                      sourceDate: n.sourceDate,
                      syllabusTag: n.syllabusTag,
                      asOfDate: n.asOfDate,
                      isExamRelevant: n.isExamRelevant,
                    ),
                ],
              ),
            HomeMenuTile(
              icon: Icons.edit_note_outlined,
              title: '間違いノート',
              subtitle: '間違えた問題を見返して、解き直せます。',
              onTap: () =>
                  openMistakeNote(context, exam: exam, questions: questions, terms: terms),
            ),
            // しおり・メモ（core のカード）。
            StudyNotesHomeCards(
                loadQuestions: () async => questions, detailBuilder: _detailBuilder),
            const SizedBox(height: 4),
            HomeMenuTile(
              icon: Icons.menu_book_outlined,
              title: '用語集',
              subtitle: '収録${terms.length}語。わからない用語をいつでも調べられます。',
              onTap: () => _push(context, '用語集', TermsScreen(exam: exam, terms: terms)),
            ),
            if (chapterReadings.isNotEmpty) ...[
              const SizedBox(height: 8),
              HomeMenuTile(
                icon: Icons.auto_stories_outlined,
                title: '章ごとの解説読み物',
                subtitle: '公式の章立てに沿って、学習項目を体系的に読めます。',
                onTap: () => _push(
                  context,
                  '章ごとの解説読み物',
                  ReadingListScreen(
                    readings: chapterReadings,
                    terms: terms,
                    questions: questions,
                    termReferences: termReferences,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            HomeMenuTile(
              icon: Icons.hub_outlined,
              title: '用語マップ・AI系譜図',
              subtitle: '関連する用語をつないだ地図と、AIの歴史のタイムラインです。',
              onTap: () => _push(context, '用語マップ・AI系譜図', TermMapScreen(terms: terms)),
            ),
          ],
        ),
      ),
    );
  }
}
