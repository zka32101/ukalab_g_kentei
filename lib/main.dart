import 'dart:io' show Platform;

import 'package:app_common_kit/app_common_kit.dart' hide SettingsScreen;
import 'package:ukalab_core/ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ukalab_core/daily_goal.dart';
import 'package:ukalab_core/reminder.dart' show reminderOverrides;
import 'package:ukalab_core/exam_date.dart';
import 'data/exam_repository.dart';
import 'screens/home_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/mock_exam_screen.dart';
import 'screens/record_screen.dart';
import 'screens/settings_screen.dart';
import 'services/no_ads_backend.dart';

/// Google公式のテスト広告ユニットID。本番公開前に実際のIDへ差し替える（決定35）。
AdUnitIds _testAdUnitIds() => kIsWeb
    // Web には広告SDKが無く、広告は出さない（NoAdsBackend）。リリースビルドでテストIDを
    // 使うと AdGate が例外にするため、Web では空のIDにする。
    ? const AdUnitIds(banner: '', interstitial: '', rewarded: '')
    : Platform.isIOS
    ? const AdUnitIds(
        banner: 'ca-app-pub-3940256099942544/2934735716',
        interstitial: 'ca-app-pub-3940256099942544/4411468910',
        rewarded: 'ca-app-pub-3940256099942544/1712485313',
      )
    : const AdUnitIds(
        banner: 'ca-app-pub-3940256099942544/6300978111',
        interstitial: 'ca-app-pub-3940256099942544/1033173712',
        rewarded: 'ca-app-pub-3940256099942544/5224354917',
      );

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 同梱フォントのライセンス（SIL OFL 1.1）を、設定のライセンス表示へ載せる。
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      ['BIZ UDPGothic'],
      await rootBundle.loadString('assets/fonts/OFL.txt'),
    );
  });

  // 学習コイン・衣装（app_common_kit）。財布・衣装台帳はアプリごとに端末内保存
  // （決定67〜77）。ショップには通常衣装（G検定、コイン購入）だけを並べる。
  final coinService = CoinService(
    store: SharedPreferencesCoinStore('g_kentei'),
    shop: OutfitCatalog.shopItems([UkalabCert.gKentei]),
  );
  await coinService.load();

  final outfitService = OutfitService(store: SharedPreferencesOutfitStore('g_kentei'));
  await outfitService.load();

  // 課金（RevenueCat）。実際のAPIキー取得後にRevenueCatEntitlementServiceへ
  // 差し替える。価格は競合調査を踏まえた暫定値で、運営者確認が必要（決定14）。
  final entitlementService = FakeEntitlementService(
    availableOffers: const [
      EntitlementOffer(
        id: 'noads',
        productId: 'g_kentei_noads',
        title: '広告非表示',
        priceString: '¥480',
      ),
      EntitlementOffer(
        id: 'premium',
        productId: 'g_kentei_premium',
        title: 'プレミアム（広告非表示＋追加機能）',
        priceString: '¥1,500',
      ),
    ],
    grantOnPurchase: const {
      'g_kentei_noads': EntitlementState(hasNoAds: true),
      'g_kentei_premium': EntitlementState(hasPremium: true),
    },
  );

  // 広告（AdMob、決定35）。noads/premiumの間は何も表示しない。
  final adGate = await AdGate.init(
    config: AdConfig(unitIds: _testAdUnitIds()),
    // Web には広告SDK（google_mobile_ads）が無いため、広告を出さない実装にする。
    backend: kIsWeb ? NoAdsBackend() : null,
    adsHidden: () => entitlementService.state.adsHidden,
    isRelease: kReleaseMode,
  );

  // 全国平均点・偏差値の匿名集計（決定32）。Firebaseプロジェクトを取得後、
  // FirebaseExamStatsService へ差し替える（firebase_core の初期化が必要）。
  final examStatsService = FakeExamStatsService();

  // ブックマーク・タグ・問題メモ（端末内に保存）。
  final studyNotes = await studyNotesOverrides('g_kentei');

  // デイリーミッション（今日の目標問題数）と学習カレンダー用の履歴。端末内に保存する。
  final dailyGoal = await dailyGoalOverrides('g_kentei');
  final reminder = await reminderOverrides('g_kentei');

  final container = ProviderContainer(
    overrides: [
      coinServiceProvider.overrideWithValue(coinService),
      outfitServiceProvider.overrideWithValue(outfitService),
      entitlementServiceProvider.overrideWithValue(entitlementService),
      adGateProvider.overrideWithValue(adGate),
      examStatsServiceProvider.overrideWithValue(examStatsService),
      handsFreeStoreProvider.overrideWithValue(SharedPreferencesHandsFreeStore('g_kentei')),
      examDateStoreProvider.overrideWithValue(ExamDateStore('g_kentei')),
      ...studyNotes,
      ...dailyGoal,
      ...reminder,
    ],
  );
  await container.read(handsFreeProvider.notifier).load();
  await container.read(examDateProvider.notifier).load();

  runApp(UncontrolledProviderScope(
    container: container,
    child: const UkalabGKenteiApp(),
  ));
}

/// 同梱フォント（BIZ UDPGothic）。端末のフォントで漢字の字形が変わるのを防ぐ。
const kAppFontFamily = 'BIZUDPGothic';

ThemeData _withFont(ThemeData t) => t.copyWith(
      textTheme: t.textTheme.apply(fontFamily: kAppFontFamily),
      primaryTextTheme: t.primaryTextTheme.apply(fontFamily: kAppFontFamily),
    );

class UkalabGKenteiApp extends StatelessWidget {
  const UkalabGKenteiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'うかラボ G検定',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja', 'JP'),
      theme: _withFont(UkalabTheme.light(field: UkalabField.ai, cert: UkalabCert.gKentei)),
      darkTheme: _withFont(UkalabTheme.dark(field: UkalabField.ai, cert: UkalabCert.gKentei)),
      home: const _RootPage(),
    );
  }
}

class _RootPage extends ConsumerWidget {
  const _RootPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examData = ref.watch(examDataProvider);
    return examData.when(
      loading: () => const StartupSplash(),
      error: (e, st) => Scaffold(
        body: ErrorState(
          message: '問題データを読み込めませんでした。\n$e',
          onRetry: () => ref.invalidate(examDataProvider),
        ),
      ),
      data: (data) {
        final questions = data.activeQuestions;
        return UkalabShell(
          pages: [
            HomeScreen(
              exam: data.exam,
              questions: questions,
              terms: data.terms,
              boundaryScenarios: data.boundaryScenarios,
              predictRunScenarios: data.predictRunScenarios,
              misconceptionScenarios: data.misconceptionScenarios,
              failureCases: data.failureCases,
              confusionMatrixScenarios: data.confusionMatrixScenarios,
              methodChoiceScenarios: data.methodChoiceScenarios,
              mlLabDatasets: data.mlLabDatasets,
              aiNewsItems: data.aiNewsItems,
              convLabImages: data.convLabImages,
              attentionVizScenarios: data.attentionVizScenarios,
              nnBuilderDatasets: data.nnBuilderDatasets,
              ethicsCaseScenarios: data.ethicsCaseScenarios,
              storyScenarios: data.storyScenarios,
            ),
            LearnScreen(questions: questions, terms: data.terms),
            MockExamScreen(exam: data.exam, questions: questions),
            RecordScreen(exam: data.exam, questions: questions),
            SettingsScreen(questions: questions),
          ],
        );
      },
    );
  }
}
