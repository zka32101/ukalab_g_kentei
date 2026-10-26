import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:ukalab_core/ukalab_core.dart';

import '../widgets/ai_draft_notice.dart';

/// 「AI倫理ケース」一覧（画期的な機能7）。架空のケースに対して公平性・
/// プライバシー・説明責任・著作権などの観点から適切な判断を選ぶ。UIは
/// 「手法の選び方」と同じ MethodChoiceWidget を再利用する。
class EthicsCaseScreen extends StatelessWidget {
  const EthicsCaseScreen({super.key, required this.scenarios});

  final List<EthicsCaseScenario> scenarios;

  @override
  Widget build(BuildContext context) {
    if (scenarios.isEmpty) {
      return const EmptyState(message: 'AI倫理ケースのデータがまだありません。');
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: scenarios.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final s = scenarios[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.psychology_outlined),
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
                        MethodChoiceWidget(
                      scenario: MethodChoiceScenarioSpec(
                        title: s.title,
                        caseDescription: s.caseDescription,
                        options: [
                          for (final o in s.options)
                            FailureChoiceSpec(
                              optionId: o.optionId,
                              text: o.text,
                              isCorrect: o.isCorrect,
                            ),
                        ],
                        explanation: s.explanation,
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
