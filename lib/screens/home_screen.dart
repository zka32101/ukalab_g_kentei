import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart';

import 'package:ukalab_core/daily_goal.dart' show DailyMissionCard;
import 'package:ukalab_core/reminder.dart' show StudyReminderCard;
import 'package:ukalab_core/exam_date.dart';
import '../data/exam_repository.dart';
import '../widgets/oshi_card.dart';
import '../widgets/oshi_home_cards.dart';
import 'mistake_note_screen.dart';
import 'nagara_entry.dart';
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
import 'exam_prep_entry.dart';
import 'premium_practice_cards.dart';
import 'predict_run_screen.dart';
import 'reading_screen.dart';
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
    required this.chapterReadings,
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
  final List<ChapterReading> chapterReadings;

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
    final userDate = ref.watch(examDateProvider);
    final theme = Theme.of(context);
    final adGate = ref.watch(adGateProvider);
    final termReferences = ref.watch(examDataProvider).valueOrNull?.termReferences ?? const [];
    final examDate = userDate ?? (exam.examDates.isEmpty ? null : exam.examDates.first);

    // 体験ラボ（データがあるものだけ並べる。条件は従来どおり）。
    final labItems = <HomeMenuItem>[
      if (boundaryScenarios.isNotEmpty)
        HomeMenuItem(
          icon: Icons.balance_outlined,
          title: 'AIと法律の境界線',
          onTap: () => _push(context, 'AIと法律の境界線', BoundaryScreen(scenarios: boundaryScenarios)),
        ),
      if (predictRunScenarios.isNotEmpty)
        HomeMenuItem(
          icon: Icons.timeline_outlined,
          title: '予測→実行',
          onTap: () => _push(context, '予測→実行', PredictRunScreen(scenarios: predictRunScenarios)),
        ),
      if (misconceptionScenarios.isNotEmpty)
        HomeMenuItem(
          icon: Icons.edit_note_outlined,
          title: '推しの答案を添削',
          onTap: () =>
              _push(context, '推しの答案を添削', TeachMascotScreen(scenarios: misconceptionScenarios)),
        ),
      if (failureCases.isNotEmpty)
        HomeMenuItem(
          icon: Icons.show_chart_outlined,
          title: '学習の失敗図鑑',
          onTap: () => _push(context, '学習の失敗図鑑', FailureGalleryScreen(cases: failureCases)),
        ),
      if (confusionMatrixScenarios.isNotEmpty)
        HomeMenuItem(
          icon: Icons.grid_on_outlined,
          title: '評価指標ラボ',
          onTap: () =>
              _push(context, '評価指標ラボ', ConfusionMatrixLabScreen(scenarios: confusionMatrixScenarios)),
        ),
      if (methodChoiceScenarios.isNotEmpty)
        HomeMenuItem(
          icon: Icons.rule_folder_outlined,
          title: '手法の選び方',
          onTap: () => _push(context, '手法の選び方', MethodChoiceScreen(scenarios: methodChoiceScenarios)),
        ),
      if (mlLabDatasets.isNotEmpty)
        HomeMenuItem(
          icon: Icons.scatter_plot_outlined,
          title: '機械学習ラボ',
          onTap: () => _push(context, '機械学習ラボ', MlLabScreen(datasets: mlLabDatasets)),
        ),
      if (convLabImages.isNotEmpty)
        HomeMenuItem(
          icon: Icons.grid_view_outlined,
          title: '画像認識の中身を見る',
          onTap: () => _push(context, '画像認識の中身を見る', ConvLabScreen(images: convLabImages)),
        ),
      if (attentionVizScenarios.isNotEmpty)
        HomeMenuItem(
          icon: Icons.share_outlined,
          title: 'Transformerの注意の可視化',
          onTap: () => _push(
              context, 'Transformerの注意の可視化', AttentionVizScreen(scenarios: attentionVizScenarios)),
        ),
      if (nnBuilderDatasets.isNotEmpty)
        HomeMenuItem(
          icon: Icons.account_tree_outlined,
          title: 'ニューラルネット組み立て',
          onTap: () => _push(context, 'ニューラルネット組み立て', NnBuilderScreen(datasets: nnBuilderDatasets)),
        ),
      if (ethicsCaseScenarios.isNotEmpty)
        HomeMenuItem(
          icon: Icons.psychology_outlined,
          title: 'AI倫理ケース',
          onTap: () => _push(context, 'AI倫理ケース', EthicsCaseScreen(scenarios: ethicsCaseScenarios)),
        ),
      if (storyScenarios.isNotEmpty)
        HomeMenuItem(
          icon: Icons.auto_graph_outlined,
          title: 'AIプロジェクト経営モード',
          onTap: () => _push(context, 'AIプロジェクト経営モード', AiProjectScreen(scenarios: storyScenarios)),
        ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                OshiCard(totalQuestions: questions.length, examDate: examDate),
                const SizedBox(height: 8),
                // 推しの一言(無料)。タップで別の一言。
                OshiMessageCard(examDate: examDate),
              ],
            ),
          ),
          // ① 今日やること
          _PersistedSection(
            id: 'today',
            title: '今日やること',
            subtitle: '今日の一歩をここから',
            leading: const Icon(Icons.today_outlined),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const DailyMissionCard(),
                  const StudyReminderCard(),
                  // ながらセッション(無料。耳で聞いて自動で進む)。
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: NagaraEntryCard(exam: exam, questions: questions, terms: terms),
                  ),
                  PremiumPracticeCards(exam: exam, questions: questions, terms: terms),
                  const SizedBox(height: 4),
                  HomeMenuTile(
                    icon: Icons.route_outlined,
                    title: '最短ルートプランナー',
                    subtitle: '残り日数・弱点から「今日やる3つ」を出します。',
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
                  const SizedBox(height: 8),
                  HomeMenuTile(
                    icon: Icons.timer_outlined,
                    title: '145問ペース走',
                    subtitle: '本番のペース感覚を短縮版（20問・14分）で体感します。',
                    onTap: () => _push(context, '145問ペース走', PaceRunScreen(questions: questions)),
                  ),
                  const SizedBox(height: 8),
                  HomeMenuTile(
                    icon: Icons.edit_note_outlined,
                    title: '間違いノート',
                    subtitle: '間違えた問題を見返して、解き直せます。',
                    onTap: () =>
                        openMistakeNote(context, exam: exam, questions: questions, terms: terms),
                  ),
                ],
              ),
            ),
          ),
          // ② 記録
          _PersistedSection(
            id: 'record',
            title: '記録',
            subtitle: 'これまでの歩みをふりかえる',
            leading: const Icon(Icons.insights_outlined),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 週間ふりかえり(無料。今週できたことだけを見せる)。
                  WeeklyRecapSection(exam: exam, questions: questions),
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
                ],
              ),
            ),
          ),
          // ③ 試験に向けて
          _PersistedSection(
            id: 'exam',
            title: '試験に向けて',
            subtitle: '試験日と直前の備え',
            leading: const Icon(Icons.flag_outlined),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ExamCountdownEntry(exam: exam),
                  CoreFeaturesCard(exam: exam, questions: questions, terms: terms),
                ],
              ),
            ),
          ),
          // ④ 道具
          _PersistedSection(
            id: 'tools',
            title: '道具',
            subtitle: '調べる・見返す',
            leading: const Icon(Icons.handyman_outlined),
            collapsible: true,
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
          ),
          // ⑤ 体験ラボ（数が多いので初期は畳む。開閉は端末に保存）
          if (labItems.isNotEmpty)
            _PersistedSection(
              id: 'lab',
              title: '体験ラボ',
              subtitle: '動かして理解する',
              leading: const Icon(Icons.science_outlined),
              collapsible: true,
              initiallyExpanded: false,
              child: HomeMenuGrid(items: labItems),
            ),
          const SizedBox(height: 16),
          Center(child: adGate.banner(BannerPlacement.home)),
        ],
      ),
    );
  }
}

/// 見出し付きグループ。畳めるグループは開閉を SharedPreferences に保存する
/// （キー `ukalab_g_kentei_home_section_<id>`）。読めなくても既定の開閉で動く。
class _PersistedSection extends StatefulWidget {
  const _PersistedSection({
    required this.id,
    required this.title,
    required this.child,
    this.subtitle,
    this.leading,
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  final String id;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool collapsible;
  final bool initiallyExpanded;
  final Widget child;

  @override
  State<_PersistedSection> createState() => _PersistedSectionState();
}

class _PersistedSectionState extends State<_PersistedSection> {
  late final ValueNotifier<bool> _expanded = ValueNotifier(widget.initiallyExpanded);

  String get _key => 'ukalab_g_kentei_home_section_${widget.id}';

  @override
  void initState() {
    super.initState();
    if (widget.collapsible) _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_key);
      if (saved != null && mounted) _expanded.value = saved;
    } catch (_) {
      // 保存値が読めなくても既定の開閉で表示する。
    }
  }

  Future<void> _save(bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, v);
    } catch (_) {}
  }

  @override
  void dispose() {
    _expanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HomeSection(
        title: widget.title,
        subtitle: widget.subtitle,
        leading: widget.leading,
        collapsible: widget.collapsible,
        initiallyExpanded: widget.initiallyExpanded,
        expandedListenable: widget.collapsible ? _expanded : null,
        onExpandedChanged: widget.collapsible ? _save : null,
        child: widget.child,
      );
}
