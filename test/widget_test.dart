import 'package:app_common_kit/app_common_kit.dart';
import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_g_kentei/main.dart';

import 'test_support.dart';

// MascotWidget は animate: true が既定のため、disableAnimations なしでは
// アニメーションが回り続けて pumpAndSettle がタイムアウトする。
Future<Widget> _app() async => ProviderScope(
      overrides: [
        handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
        ...studyNotesTestOverrides(),
        coinServiceProvider.overrideWithValue(CoinService(store: InMemoryCoinStore())),
        outfitServiceProvider.overrideWithValue(OutfitService(store: InMemoryOutfitStore())),
        entitlementServiceProvider.overrideWithValue(FakeEntitlementService(
          availableOffers: const [
            EntitlementOffer(
              id: 'noads',
              productId: 'g_kentei_noads',
              title: '広告非表示',
              priceString: '¥480',
            ),
          ],
          grantOnPurchase: const {
            'g_kentei_noads': EntitlementState(hasNoAds: true),
          },
        )),
        adGateProvider.overrideWithValue(await testAdGate()),
        examStatsServiceProvider.overrideWithValue(FakeExamStatsService()),
      ],
      child: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: const UkalabGKenteiApp(),
      ),
    );

void main() {
  testWidgets('起動して問題データを読み込み、ホーム画面が表示される', (tester) async {
    // assets からの読み込みは実際の非同期I/Oのため、pump だけでは
    // fake async のタイミングと競合してタイムアウトすることがある。
    // runAsync で実際の非同期ガップを許可してから反映させる。
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.text('うかラボ G検定'), findsOneWidget);
    expect(find.text('ホーム'), findsOneWidget);
    expect(find.text('学ぶ'), findsOneWidget);
    expect(find.text('模擬'), findsOneWidget);
  });

  testWidgets('用語集を開いて検索し、用語カードが開く', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('用語集'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('用語集'));
    await tester.pumpAndSettle();
    expect(find.text('用語を検索'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '過学習');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, '過学習'), findsOneWidget);

    await tester.tap(find.widgetWithText(ListTile, '過学習'));
    await tester.pumpAndSettle();
    expect(find.byType(TermCard), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TermCard),
        matching: find.text('練習問題は得意だが、新しい問題には弱くなること'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('境界線スライダーを開いて条件を切り替えると判定が変わる', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('AIと法律の境界線'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AIと法律の境界線'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('学習用データの収集（著作権法30条の4）'));
    await tester.pumpAndSettle();
    expect(find.byType(BoundarySliderWidget), findsOneWidget);

    await tester.tap(find.text('作品の思想・感情を享受させる目的を含むか'));
    await tester.pumpAndSettle();
    expect(find.textContaining('享受目的を含むため'), findsOneWidget);
  });

  testWidgets('予測→実行を開いて予測すると正解とのズレが出る', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('予測→実行'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('予測→実行'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('検査のパラドックス'));
    await tester.pumpAndSettle();
    expect(find.byType(PredictRunWidget), findsOneWidget);

    await tester.tap(find.text('予測する'));
    await tester.pumpAndSettle();
    expect(find.text('正解'), findsOneWidget);
    expect(find.text('15%'), findsOneWidget);
  });

  testWidgets('推しの答案を添削を開いて正解をタップすると解説が出る', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('推しの答案を添削'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('推しの答案を添削'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('過学習の対策'));
    await tester.pumpAndSettle();
    expect(find.byType(TeachMascotWidget), findsOneWidget);
    expect(find.text('ここが分からない…'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '未知データでの性能(汎化性能)'));
    await tester.pumpAndSettle();
    expect(find.text('わかった!'), findsOneWidget);
  });

  testWidgets('最短ルートプランナーを開くと今日やる3つが出る', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('最短ルートプランナー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('最短ルートプランナー'));
    await tester.pumpAndSettle();

    expect(find.byType(RoutePlannerWidget), findsOneWidget);
    expect(find.text('今日やる3つ'), findsOneWidget);
  });

  testWidgets('145問ペース走を開くと説明と開始ボタンが出る', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('145問ペース走'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('145問ペース走'));
    await tester.pumpAndSettle();

    expect(find.text('ペース走を始める'), findsOneWidget);
  });

  testWidgets('学習の失敗図鑑を開いて症状・処方に正解すると解説が出る', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('学習の失敗図鑑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('学習の失敗図鑑'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('症例1'));
    await tester.pumpAndSettle();
    expect(find.byType(FailureGalleryWidget), findsOneWidget);
    expect(find.text('この学習曲線の症状は?'), findsOneWidget);

    final symptom = find.widgetWithText(ChoiceChip, '過学習');
    await tester.ensureVisible(symptom);
    await tester.tap(symptom);
    await tester.pumpAndSettle();
    expect(find.text('この症状への処方は?'), findsOneWidget);

    final treatment = find.widgetWithText(ChoiceChip, '正則化(Dropoutなど)を強める、またはデータを増やす');
    await tester.ensureVisible(treatment);
    await tester.tap(treatment);
    await tester.pumpAndSettle();
    expect(find.text('わかった!'), findsOneWidget);
  });

  testWidgets('設定タブで購入すると購入済み表示になる', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();
    expect(find.text('広告非表示'), findsOneWidget);

    await tester.tap(find.text('¥480'));
    await tester.pumpAndSettle();
    expect(find.text('広告非表示を購入済みです'), findsOneWidget);
  });

  testWidgets('用語マップ・AI系譜図を開くと系譜図と用語マップが出て、タップで用語カードが開く', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('用語マップ・AI系譜図'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('用語マップ・AI系譜図'));
    await tester.pumpAndSettle();

    expect(find.text('AIの歴史（系譜図）'), findsOneWidget);
    expect(find.text('用語マップ（関連でつながる用語）'), findsOneWidget);

    final node = find.text('生成AI').first;
    await tester.ensureVisible(node);
    await tester.tap(node);
    await tester.pumpAndSettle();
    expect(find.byType(TermCard), findsOneWidget);
  });

  testWidgets('評価指標ラボを開いて場面の選択肢に正解すると解説が出る', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('評価指標ラボ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('評価指標ラボ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('がん検診'));
    await tester.pumpAndSettle();
    expect(find.byType(ConfusionMatrixLabWidget), findsOneWidget);

    final choice = find.text('再現率を優先する（見逃しを減らす）');
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.pumpAndSettle();
    expect(find.text('わかった!'), findsOneWidget);
  });

  testWidgets('手法の選び方を開いて正しい手法を選ぶと解説が出る', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('手法の選び方'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('手法の選び方'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('顧客の離脱予測'));
    await tester.pumpAndSettle();
    expect(find.byType(MethodChoiceWidget), findsOneWidget);

    final choice = find.text('分類（教師あり学習）');
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.pumpAndSettle();
    expect(find.text('わかった!'), findsOneWidget);
  });

  testWidgets('機械学習ラボを開いて手法を切り替えられる', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('機械学習ラボ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('機械学習ラボ'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('XORパターン（線形分離できない例）'));
    await tester.pumpAndSettle();
    expect(find.byType(MlLabWidget), findsOneWidget);

    await tester.tap(find.text('決定木'));
    await tester.pumpAndSettle();
    expect(find.text('深さ'), findsOneWidget);
  });

  testWidgets('今月のAI動向は、掲載データが無い間はホームに出ない（実在しない出典URLの仮データを出さない）',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.text('今月のAI動向'), findsNothing);
    expect(find.byType(AiNewsCard), findsNothing);
  });

  testWidgets('画像認識の中身を見るを開いてフィルタを切り替えられる', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('画像認識の中身を見る'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('画像認識の中身を見る'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('手書き風の「1」'));
    await tester.pumpAndSettle();
    expect(find.byType(ConvLabWidget), findsOneWidget);

    await tester.tap(find.text('ぼかし'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('Transformerの注意の可視化を開いて単語を切り替えられる', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Transformerの注意の可視化'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transformerの注意の可視化'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('誰が何を食べた？'));
    await tester.pumpAndSettle();
    expect(find.byType(AttentionVizWidget), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '食べた'));
    await tester.pumpAndSettle();
    expect(find.textContaining('「食べた」は'), findsOneWidget);
  });

  testWidgets('ニューラルネット組み立てを開いて隠れ層の数を切り替えられる', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ニューラルネット組み立て'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ニューラルネット組み立て'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('XORパターン（隠れ層で分けられるか）'));
    await tester.pumpAndSettle();
    expect(find.byType(NnBuilderWidget), findsOneWidget);

    await tester.tap(find.text('2層'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('AI倫理ケースを開いて正しい判断を選ぶと解説が出る', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('AI倫理ケース'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI倫理ケース'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('採用AIの偏り'));
    await tester.pumpAndSettle();
    expect(find.byType(MethodChoiceWidget), findsOneWidget);

    final choice = find.text('公平性（アルゴリズムバイアス・差別）');
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.pumpAndSettle();
    expect(find.text('わかった!'), findsOneWidget);
  });

  testWidgets('AIプロジェクト経営モードを開いて章を進められる', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(await _app());
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('AIプロジェクト経営モード'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AIプロジェクト経営モード'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('架空の小売企業でAI導入'));
    await tester.pumpAndSettle();
    expect(find.byType(StoryModeWidget), findsOneWidget);
    expect(find.text('第1章 / 全6章'), findsOneWidget);

    final choice = find.text('社内の購買履歴データを、個人情報保護の方針に沿って匿名化しながら収集する');
    await tester.ensureVisible(choice);
    await tester.tap(choice);
    await tester.pumpAndSettle();
    expect(find.text('よい判断です'), findsOneWidget);

    await tester.tap(find.text('次の章へ'));
    await tester.pumpAndSettle();
    expect(find.text('第2章 / 全6章'), findsOneWidget);
  });
}
