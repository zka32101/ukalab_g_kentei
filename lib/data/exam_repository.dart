import 'dart:convert';

import 'package:app_common_kit/app_common_kit.dart' show TermReference;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ukalab_core.dart';

/// G検定の試験定義・問題データ・用語データを assets から読み込む。
class ExamData {
  const ExamData({
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

  /// 境界線スライダー（型①、決定76・77）の場面一覧。
  final List<BoundaryScenario> boundaryScenarios;

  /// 予測→実行（型②、決定76）の場面一覧。
  final List<PredictRunScenario> predictRunScenarios;

  /// 推しの答案を添削（型③、決定76・77）の場面一覧。
  final List<MisconceptionScenario> misconceptionScenarios;

  /// 学習の失敗図鑑（型⑦、決定76）の症例一覧。
  final List<FailureCase> failureCases;

  /// 評価指標ラボ（画期的な機能3）の場面一覧。
  final List<ConfusionMatrixScenario> confusionMatrixScenarios;

  /// 手法の選び方（事例仕分け、画期的な機能6）の場面一覧。
  final List<MethodChoiceScenario> methodChoiceScenarios;

  /// 機械学習ラボ（画期的な機能1）のデータセット一覧。
  final List<MlLabDataset> mlLabDatasets;

  /// 今月のAI動向（画期的な機能10）の一覧。
  final List<AiNewsItem> aiNewsItems;

  /// 画像認識の中身を見る（画期的な機能4）の画像一覧。
  final List<ConvLabImage> convLabImages;

  /// Transformerの注意の可視化（画期的な機能5）の場面一覧。
  final List<AttentionVizScenario> attentionVizScenarios;

  /// ニューラルネット組み立て（画期的な機能2）のデータセット一覧。
  final List<NnBuilderDataset> nnBuilderDatasets;

  /// AI倫理ケース（画期的な機能7）の場面一覧。
  final List<EthicsCaseScenario> ethicsCaseScenarios;

  /// AIプロジェクト経営モード（画期的な機能8、ストーリー型）のシナリオ一覧。
  final List<StoryScenario> storyScenarios;

  /// 章ごとの解説読み物（教科書的なまとめページ）の一覧。
  final List<ChapterReading> chapterReadings;

  List<Question> get activeQuestions =>
      questions.where((q) => !q.disabled).toList();

  Term? termById(String termId) {
    for (final t in terms) {
      if (t.termId == termId) return t;
    }
    return null;
  }

  /// 問題文・解説文中の用語をタップ可能にするための、見出し語ベースの参照一覧。
  List<TermReference> get termReferences => [
        for (final t in terms) TermReference(termId: t.termId, matchText: t.term),
      ];
}

Future<ExamData> loadExamData() async {
  final examText = await rootBundle.loadString('assets/exam/g_kentei.json');
  final exam = ExamConfig.fromJson(jsonDecode(examText) as Map<String, dynamic>);

  final jsonl = await rootBundle.loadString('assets/questions/g_kentei.jsonl');
  final parsed = parseQuestionsJsonl(jsonl);

  final termsJsonl = await rootBundle.loadString('assets/terms/g_kentei.jsonl');
  final parsedTerms = parseTermsJsonl(termsJsonl);

  final boundaryJsonl =
      await rootBundle.loadString('assets/experience/g_kentei.jsonl');
  final parsedBoundary = parseBoundaryScenariosJsonl(boundaryJsonl);

  final predictJsonl =
      await rootBundle.loadString('assets/experience/predict_g_kentei.jsonl');
  final parsedPredict = parsePredictRunScenariosJsonl(predictJsonl);

  final misconceptionJsonl = await rootBundle
      .loadString('assets/experience/teach_mascot_g_kentei.jsonl');
  final parsedMisconception = parseMisconceptionScenariosJsonl(misconceptionJsonl);

  final failureJsonl = await rootBundle
      .loadString('assets/experience/failure_gallery_g_kentei.jsonl');
  final parsedFailure = parseFailureCasesJsonl(failureJsonl);

  final confusionMatrixJsonl = await rootBundle
      .loadString('assets/experience/confusion_matrix_lab_g_kentei.jsonl');
  final parsedConfusionMatrix =
      parseConfusionMatrixScenariosJsonl(confusionMatrixJsonl);

  final methodChoiceJsonl = await rootBundle
      .loadString('assets/experience/method_choice_g_kentei.jsonl');
  final parsedMethodChoice = parseMethodChoiceScenariosJsonl(methodChoiceJsonl);

  final mlLabJsonl = await rootBundle.loadString('assets/experience/ml_lab_g_kentei.jsonl');
  final parsedMlLab = parseMlLabDatasetsJsonl(mlLabJsonl);

  final aiNewsJsonl = await rootBundle.loadString('assets/experience/ai_news_g_kentei.jsonl');
  final parsedAiNews = parseAiNewsItemsJsonl(aiNewsJsonl);

  final convLabJsonl = await rootBundle.loadString('assets/experience/conv_lab_g_kentei.jsonl');
  final parsedConvLab = parseConvLabImagesJsonl(convLabJsonl);

  final attentionVizJsonl =
      await rootBundle.loadString('assets/experience/attention_viz_g_kentei.jsonl');
  final parsedAttentionViz = parseAttentionVizScenariosJsonl(attentionVizJsonl);

  final nnBuilderJsonl =
      await rootBundle.loadString('assets/experience/nn_builder_g_kentei.jsonl');
  final parsedNnBuilder = parseNnBuilderDatasetsJsonl(nnBuilderJsonl);

  final ethicsCaseJsonl =
      await rootBundle.loadString('assets/experience/ethics_case_g_kentei.jsonl');
  final parsedEthicsCase = parseEthicsCaseScenariosJsonl(ethicsCaseJsonl);

  final storyJsonl =
      await rootBundle.loadString('assets/experience/story_mode_g_kentei.jsonl');
  final parsedStory = parseStoryScenariosJsonl(storyJsonl);

  final readingJsonl =
      await rootBundle.loadString('assets/experience/reading_g_kentei.jsonl');
  final parsedReading = parseChapterReadingsJsonl(readingJsonl);

  final issues = [
    ...parsed.issues,
    ...validateQuestions(parsed.questions, exam: exam),
    ...parsedTerms.issues,
    ...validateTerms(parsedTerms.terms, exam: exam, questions: parsed.questions),
    ...parsedBoundary.issues,
    ...validateBoundaryScenarios(parsedBoundary.scenarios, exam: exam),
    ...parsedPredict.issues,
    ...validatePredictRunScenarios(parsedPredict.scenarios, exam: exam),
    ...parsedMisconception.issues,
    ...validateMisconceptionScenarios(parsedMisconception.scenarios, exam: exam),
    ...parsedFailure.issues,
    ...validateFailureCases(parsedFailure.cases, exam: exam),
    ...parsedConfusionMatrix.issues,
    ...validateConfusionMatrixScenarios(parsedConfusionMatrix.scenarios, exam: exam),
    ...parsedMethodChoice.issues,
    ...validateMethodChoiceScenarios(parsedMethodChoice.scenarios, exam: exam),
    ...parsedMlLab.issues,
    ...validateMlLabDatasets(parsedMlLab.datasets, exam: exam),
    ...parsedAiNews.issues,
    ...validateAiNewsItems(
      parsedAiNews.items,
      exam: exam,
      questionIds: parsed.questions.map((q) => q.qid).toList(),
    ),
    ...parsedConvLab.issues,
    ...validateConvLabImages(parsedConvLab.images, exam: exam),
    ...parsedAttentionViz.issues,
    ...validateAttentionVizScenarios(parsedAttentionViz.scenarios, exam: exam),
    ...parsedNnBuilder.issues,
    ...validateNnBuilderDatasets(parsedNnBuilder.datasets, exam: exam),
    ...parsedEthicsCase.issues,
    ...validateEthicsCaseScenarios(parsedEthicsCase.scenarios, exam: exam),
    ...parsedStory.issues,
    ...validateStoryScenarios(parsedStory.scenarios, exam: exam),
    ...parsedReading.issues,
    ...validateChapterReadings(
      parsedReading.items,
      exam: exam,
      termIds: parsedTerms.terms.map((t) => t.termId).toList(),
      questionIds: parsed.questions.map((q) => q.qid).toList(),
    ),
  ];
  if (issues.isNotEmpty) {
    throw StateError('問題・用語データに不備があります: ${issues.first}');
  }
  return ExamData(
    exam: exam,
    questions: parsed.questions,
    terms: parsedTerms.terms,
    boundaryScenarios: parsedBoundary.scenarios,
    predictRunScenarios: parsedPredict.scenarios,
    misconceptionScenarios: parsedMisconception.scenarios,
    failureCases: parsedFailure.cases,
    confusionMatrixScenarios: parsedConfusionMatrix.scenarios,
    methodChoiceScenarios: parsedMethodChoice.scenarios,
    mlLabDatasets: parsedMlLab.datasets,
    aiNewsItems: parsedAiNews.items,
    convLabImages: parsedConvLab.images,
    attentionVizScenarios: parsedAttentionViz.scenarios,
    nnBuilderDatasets: parsedNnBuilder.datasets,
    ethicsCaseScenarios: parsedEthicsCase.scenarios,
    storyScenarios: parsedStory.scenarios,
    chapterReadings: parsedReading.items,
  );
}

final examDataProvider = FutureProvider<ExamData>((ref) => loadExamData());
