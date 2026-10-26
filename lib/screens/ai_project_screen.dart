import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../widgets/ai_draft_notice.dart';

/// 「AIプロジェクト経営モード」一覧（画期的な機能8、ストーリー型）。架空の
/// 会社でAI導入を進め、各段階で判断する。UIはストーリー型の共通エンジン
/// StoryModeWidget を使う。
class AiProjectScreen extends StatelessWidget {
  const AiProjectScreen({super.key, required this.scenarios});

  final List<StoryScenario> scenarios;

  @override
  Widget build(BuildContext context) {
    if (scenarios.isEmpty) {
      return const EmptyState(message: 'AIプロジェクト経営モードのデータがまだありません。');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: scenarios.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final s = scenarios[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.auto_graph_outlined),
            title: Text(s.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: Text(s.title)),
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isAiDraftSourceRef(s.sourceRef)) const AiDraftNotice(),
                        StoryModeWidget(
                      scenario: StoryScenarioSpec(
                        title: s.title,
                        description: s.description,
                        chapters: [
                          for (final chapter in s.chapters)
                            StoryChapterSpec(
                              situation: chapter.situation,
                              choices: [
                                for (final choice in chapter.choices)
                                  StoryChoiceSpec(
                                    choiceId: choice.choiceId,
                                    text: choice.text,
                                    isRecommended: choice.isRecommended,
                                    feedback: choice.feedback,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                      ],
                    ),
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
