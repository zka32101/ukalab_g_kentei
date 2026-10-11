import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'package:ukalab_core/daily_goal.dart' show DailyMissionCard;
import 'package:ukalab_core/reminder.dart' show StudyReminderCard;
import 'package:ukalab_core/exam_date.dart';
import '../widgets/oshi_card.dart';
import 'ai_project_screen.dart';
import 'attention_viz_screen.dart';
import 'boundary_screen.dart';
import 'confusion_matrix_lab_screen.dart';
import 'conv_lab_screen.dart';
import 'ethics_case_screen.dart';
import 'failure_gallery_screen.dart';
import 'method_choice_screen.dart';
import 'ml_lab_screen.dart';
import 'nn_builder_screen.dart';
import 'pace_run_screen.dart';
import 'premium_practice_cards.dart';
import 'predict_run_screen.dart';
import 'route_planner_screen.dart';
import 'teach_mascot_screen.dart';
import 'term_map_screen.dart';
import 'terms_screen.dart';

/// 「ホーム」タブ。推し・学習コインを表示（決定67〜77）。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.exam,
    required this.questions,
    required this.terms,
    required this.boundaryScenarios,
    required this.predictRunScenarios,
    required this.misconceptionScenarios,
    required this.failureCases,
    required this.confusionMatrixScenarios,
    required this.methodChoiceScenarios,
    required this.mlLabDatasets,
    required this.aiNewsItems,
    required this.convLabImages,
    required this.attentionVizScenarios,
    required this.nnBuilderDatasets,
    required this.ethicsCaseScenarios,
    required this.storyScenarios,
  });

  final ExamConfig exam;
  final List<Question> questions;
  final List<Term> terms;
  final List<BoundaryScenario> boundaryScenarios;
  final List<PredictRunScenario> predictRunScenarios;
  final List<MisconceptionScenario> misconceptionScenarios;
  final List<FailureCase> failureCases;
  final List<ConfusionMatrixScenario> confusionMatrixScenarios;
  final List<MethodChoiceScenario> methodChoiceScenarios;
  final List<MlLabDataset> mlLabDatasets;
  final List<AiNewsItem> aiNewsItems;
  final List<ConvLabImage> convLabImages;
  final List<AttentionVizScenario> attentionVizScenarios;
  final List<NnBuilderDataset> nnBuilderDatasets;
  final List<EthicsCaseScenario> ethicsCaseScenarios;
  final List<StoryScenario> storyScenarios;

  /// 一覧から開く問題の詳細。選択肢の記号は演習（A・B・C…）に合わせる。
  Widget _detailBuilder(BuildContext context, Question q) => QuestionDetailScreen(
        question: q,
        choiceLabels: const ['A', 'B', 'C', 'D', 'E', 'F'],
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDate = ref.watch(examDateProvider);
    final theme = Theme.of(context);
    final adGate = ref.watch(adGateProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('うかラボ G検定', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'JDLA Deep Learning for GENERAL 対策（JDLAとは無関係の非公式アプリ）',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          OshiCard(
            totalQuestions: questions.length,
            examDate: userDate ?? (exam.examDates.isEmpty ? null : exam.examDates.first),
          ),
          if (aiNewsItems.isNotEmpty) ...[
            const SizedBox(height: 16),
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
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('収録問題数', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text('${questions.length}問', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text(
                    '「学ぶ」タブで分野別に演習、「模擬」タブで本番形式の採点ができます。',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const DailyMissionCard(),
          const StudyReminderCard(),
          const SizedBox(height: 16),
          PremiumPracticeCards(exam: exam, questions: questions, terms: terms),
          const SizedBox(height: 16),
          StudyNotesHomeCards(loadQuestions: () async => questions, detailBuilder: _detailBuilder),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('用語集'),
              subtitle: Text('収録${terms.length}語。わからない用語をいつでも調べられます。'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('用語集')),
                    body: TermsScreen(exam: exam, terms: terms),
                  ),
                ),
              ),
            ),
          ),
          if (boundaryScenarios.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.balance_outlined),
                title: const Text('AIと法律の境界線'),
                subtitle: const Text('条件を切り替えて、判定が変わる「境目」を体験できます。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('AIと法律の境界線')),
                      body: BoundaryScreen(scenarios: boundaryScenarios),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (predictRunScenarios.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.timeline_outlined),
                title: const Text('予測→実行'),
                subtitle: const Text('先に答えを予測してから、計算結果とのズレを体験できます。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('予測→実行')),
                      body: PredictRunScreen(scenarios: predictRunScenarios),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (misconceptionScenarios.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.edit_note_outlined),
                title: const Text('推しの答案を添削'),
                subtitle: const Text('推しの誤りをタップして直すと、「わかった!」の反応が見られます。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('推しの答案を添削')),
                      body: TeachMascotScreen(scenarios: misconceptionScenarios),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (failureCases.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.show_chart_outlined),
                title: const Text('学習の失敗図鑑'),
                subtitle: const Text('学習曲線を見て症状を当て、処方（対策）を選びます。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('学習の失敗図鑑')),
                      body: FailureGalleryScreen(cases: failureCases),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (confusionMatrixScenarios.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.grid_on_outlined),
                title: const Text('評価指標ラボ'),
                subtitle: const Text('混同行列を動かして、正解率・適合率・再現率・F値の連動を体験します。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('評価指標ラボ')),
                      body: ConfusionMatrixLabScreen(scenarios: confusionMatrixScenarios),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (methodChoiceScenarios.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.rule_folder_outlined),
                title: const Text('手法の選び方'),
                subtitle: const Text('事例に対して、適切な手法・モデル・評価指標を選びます。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('手法の選び方')),
                      body: MethodChoiceScreen(scenarios: methodChoiceScenarios),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (mlLabDatasets.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.scatter_plot_outlined),
                title: const Text('機械学習ラボ'),
                subtitle: const Text('k近傍法・決定木・線形分類の境界を見て、過学習・未学習を体験します。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('機械学習ラボ')),
                      body: MlLabScreen(datasets: mlLabDatasets),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (convLabImages.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.grid_view_outlined),
                title: const Text('画像認識の中身を見る'),
                subtitle: const Text('畳み込みフィルタを当てて、特徴マップ・プーリング後の変化を見ます。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('画像認識の中身を見る')),
                      body: ConvLabScreen(images: convLabImages),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (attentionVizScenarios.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Transformerの注意の可視化'),
                subtitle: const Text('単語同士の注意（Attention）の強さを、線の太さ・濃さで見ます。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('Transformerの注意の可視化')),
                      body: AttentionVizScreen(scenarios: attentionVizScenarios),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (nnBuilderDatasets.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: const Text('ニューラルネット組み立て'),
                subtitle: const Text('隠れ層・ユニット数・活性化関数・学習率を選び、決定境界の変化を体験します。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('ニューラルネット組み立て')),
                      body: NnBuilderScreen(datasets: nnBuilderDatasets),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (ethicsCaseScenarios.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.psychology_outlined),
                title: const Text('AI倫理ケース'),
                subtitle: const Text('架空のケースから、公平性・プライバシーなどの観点で適切な判断を選びます。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('AI倫理ケース')),
                      body: EthicsCaseScreen(scenarios: ethicsCaseScenarios),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (storyScenarios.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.auto_graph_outlined),
                title: const Text('AIプロジェクト経営モード'),
                subtitle: const Text('架空の会社でAI導入を進め、データ収集から運用・倫理審査まで判断します。'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const Text('AIプロジェクト経営モード')),
                      body: AiProjectScreen(scenarios: storyScenarios),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.route_outlined),
              title: const Text('最短ルートプランナー'),
              subtitle: const Text('残り日数・弱点から「今日やる3つ」を出します。'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => RoutePlannerScreen(
                    exam: exam,
                    level: exam.levels.first,
                    questions: questions,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('145問ペース走'),
              subtitle: const Text('本番のペース感覚を短縮版（20問・14分）で体感します。'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('145問ペース走')),
                    body: PaceRunScreen(questions: questions),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('用語マップ・AI系譜図'),
              subtitle: const Text('関連する用語をつないだ地図と、AIの歴史のタイムラインです。'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('用語マップ・AI系譜図')),
                    body: TermMapScreen(terms: terms),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: adGate.banner(BannerPlacement.home)),
        ],
      ),
    );
  }
}
