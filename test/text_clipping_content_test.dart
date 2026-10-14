import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_g_kentei/data/exam_repository.dart';
import 'package:ukalab_g_kentei/screens/learn_screen.dart';
import 'package:ukalab_g_kentei/screens/mock_exam_screen.dart';
import 'package:ukalab_g_kentei/screens/pace_run_screen.dart';

import 'layout_overflow_support.dart';
import 'test_support.dart';

/// 「長い問題文・長い選択肢・長い解説」で文字が切れないことの検査。
///
/// 出題データ（アセット）から文字数の多い問題を選び、さらに英字略語や分かち書きできない
/// 長い英字列を詰めた極端な問題も加えて、演習・模擬試験・ペース走を最後まで進める。
/// 幅 320 / 280dp × 端末の文字倍率 1 / 2 / 3 × アプリ内「文字の大きさ」標準・特大。

const _sizes = [Size(320, 640), Size(280, 560)];
const _systemScales = [1.0, 2.0, 3.0];
const _appScales = [AppTextScale.standard, AppTextScale.xLarge];

const _extreme = Question(
  qid: 'extreme',
  examId: 'g_kentei',
  subjectId: 'ml_overview',
  topicId: 't',
  prompt: 'Transformerのself-attentionで、Query・Key・Valueの内積をsqrt(d_k)で割る理由として最も適切なものはどれか。'
      'BERT、GPT-4、RLHF、LoRA、RAG、CNN、LSTM、GAN、VAE、DQN、PPO、SHAP、LIME との関係も踏まえて選べ。'
      'Backpropagation_Through_Time_Truncated_Variant_Optimization_Algorithm_Overview',
  choices: [
    '内積の分散がd_kに比例して大きくなりsoftmaxが飽和して勾配が消えるのを防ぐため（Vaswani et al., Attention Is All You Need）',
    '計算量をO(n^2)からO(n log n)に落とし、長い系列でも推論時間が線形に近づくようにするため、およびメモリ使用量を減らすため',
    'Convolutional_Neural_Network_with_Batch_Normalization_and_Residual_Connections_and_Dropout',
    '誤差逆伝播法（Backpropagation）の勾配爆発を、勾配クリッピングと同じ効果で抑えるためであり、正則化とは無関係である',
  ],
  answerIndex: 0,
  explanation: '内積 q・k の各成分が平均0・分散1の独立な確率変数だとすると、内積の分散は次元数 d_k に等しくなる。'
      'そのまま softmax に入れると一部の要素だけが極端に大きくなり、勾配がほぼ0になる（勾配消失）。'
      'sqrt(d_k) で割ることで分散を1に保ち、学習を安定させる。Transformer の他の工夫（残差接続・Layer Normalization・'
      'マルチヘッド化・位置エンコーディング）とあわせて理解しておきたい。AdamW、Warmup、Label Smoothing も頻出。',
  source: QuestionSource.original,
  sourceRef: '自作',
  contentVer: '1',
);

int _len(Question q) =>
    q.prompt.length + q.choices.fold<int>(0, (a, c) => a + c.length) + q.explanation.length;

List<Question> _longest(List<Question> all, int n) {
  final sorted = [...all]..sort((a, b) => _len(b).compareTo(_len(a)));
  return [_extreme, ...sorted.take(n - 1)];
}

late ExamData _data;

Future<void> _load(WidgetTester tester) async {
  await tester.runAsync(() async {
    _data = await loadExamData();
  });
}

Future<Widget> _host(Widget body) async {
  SharedPreferences.setMockInitialValues({});
  final coin = CoinService(store: InMemoryCoinStore());
  await coin.load();
  final container = ProviderContainer(overrides: [
    handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
    ...studyNotesTestOverrides(),
    coinServiceProvider.overrideWithValue(coin),
    outfitServiceProvider.overrideWithValue(OutfitService(store: InMemoryOutfitStore())),
    adGateProvider.overrideWithValue(await testAdGate()),
    examStatsServiceProvider.overrideWithValue(FakeExamStatsService()),
  ]);
  SharedPreferences.setMockInitialValues({});
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      builder: applyAppTextScale,
      home: Scaffold(appBar: AppBar(title: const Text('テスト')), body: body),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _scrollAll(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    final s = find.byType(Scrollable);
    if (s.evaluate().isEmpty) return;
    await tester.drag(s.first, const Offset(0, -400), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
  }
  for (var i = 0; i < 12; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 400), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 30));
  }
}

Future<bool> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  if (f.evaluate().isEmpty) return false;
  await tester.ensureVisible(f.first);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(f.first, warnIfMissed: false);
  await _settle(tester);
  return true;
}

/// ChoiceTile のうち n 番目を押す。
Future<void> _tapChoice(WidgetTester tester, int n) async {
  final tiles = find.byType(ChoiceTile);
  if (tiles.evaluate().length <= n) return;
  await tester.ensureVisible(tiles.at(n));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(tiles.at(n), warnIfMissed: false);
  await _settle(tester);
}

void main() {
  for (final size in _sizes) {
    for (final sys in _systemScales) {
      for (final app in _appScales) {
        final name = '${size.width.toInt()}dp 端末×$sys アプリ内${app.name}';
        testWidgets('長い文言でも切れない: $name', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          tester.platformDispatcher.textScaleFactorTestValue = sys;
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher.clearAllTestValues();
            appTextScale.value = AppTextScale.standard;
          });
          appTextScale.value = app;
          await _load(tester);
          final questions = _longest(_data.activeQuestions, 4);
          final c = LayoutCollector()..start();
          final out = <String, List<LayoutHit>>{};
          Future<void> step(String label, Future<void> Function() body) async {
            c.hits.clear();
            try {
              await body();
            } catch (e) {
              if (c.hits.isEmpty) c.hits.add(LayoutHit('TEST-ERROR ${e.toString().split('\n').first}', '?', shared: false));
            }
            final appHits = c.hits.where((h) => !h.shared).toList();
            for (final h in c.hits.where((h) => h.shared)) {
              debugPrint('SHARED [$name] $label: $h');
            }
            if (appHits.isNotEmpty) out[label] = appHits;
          }

          // 演習: 問題 → 誤答 → 解説 → 次へ → 正解 → 解説 → 結果。
          await step('演習', () async {
            await tester.pumpWidget(await _host(LearnScreen(
              questions: questions,
              terms: _data.terms,
              sessionSize: questions.length,
            )));
            await _settle(tester);
            expect(find.byType(ChoiceTile), findsWidgets, reason: '演習の選択肢が出ていること');
            await _scrollAll(tester);
            for (var i = 0; i < questions.length; i++) {
              await _tapChoice(tester, 1);
              await _scrollAll(tester);
              if (!await _tapText(tester, '次へ') && !await _tapText(tester, '結果を見る')) break;
            }
            await _scrollAll(tester);
          });

          // 模擬試験: 開始 → 各問に答える → 結果。
          await step('模擬試験', () async {
            await tester.pumpWidget(await _host(MockExamScreen(exam: _data.exam, questions: questions)));
            await _settle(tester);
            await _tapText(tester, '模擬試験を始める');
            expect(find.byType(ChoiceTile), findsWidgets, reason: '模擬試験の選択肢が出ていること');
            for (var i = 0; i < 6; i++) {
              await _scrollAll(tester);
              await _tapChoice(tester, 0);
              if (!await _tapText(tester, '次へ')) break;
            }
            await _scrollAll(tester);
            await _tapText(tester, '結果を見る');
            await _settle(tester);
            await _scrollAll(tester);
          });

          // ペース走: 開始 → 各問に答える → 結果。
          await step('ペース走', () async {
            await tester.pumpWidget(await _host(PaceRunScreen(questions: questions)));
            await _settle(tester);
            await _tapText(tester, 'ペース走を始める');
            expect(find.byType(ChoiceTile), findsWidgets, reason: 'ペース走の選択肢が出ていること');
            for (var i = 0; i < 25; i++) {
              if (find.byType(ChoiceTile).evaluate().isEmpty) break;
              await _scrollAll(tester);
              await _tapChoice(tester, 0);
            }
            await _scrollAll(tester);
          });

          c.stop();
          final msg = out.entries.map((e) => '${e.key}: ${e.value.join(' | ')}').join('\n');
          expect(out, isEmpty, reason: '\n$msg');
        }, timeout: const Timeout(Duration(minutes: 4)));
      }
    }
  }
}
