import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/daily_goal.dart';
import 'package:ukalab_core/ui.dart';

/// テスト用の広告バックエンド。何も表示せず、常に準備済みとして振る舞う。
class FakeAdsBackend implements AdsBackend {
  @override
  Future<bool> initialize(AdConfig config) async => true;

  @override
  Future<void> preloadInterstitial() async {}

  @override
  bool get isInterstitialReady => true;

  @override
  Future<bool> showInterstitial() async => true;

  @override
  Future<bool> showRewarded() async => true;

  @override
  Widget buildBanner(BannerPlacement placement) => const SizedBox.shrink();
}

const _testAdUnitIds = AdUnitIds(banner: 'test', interstitial: 'test', rewarded: 'test');

/// テスト用の [AdGate]。[FakeAdsBackend] を使い、SDK初期化や実際の広告表示を行わない。
Future<AdGate> testAdGate() async {
  SharedPreferences.setMockInitialValues({});
  return AdGate.init(
    config: const AdConfig(unitIds: _testAdUnitIds),
    adsHidden: () => false,
    backend: FakeAdsBackend(),
  );
}

/// しおり・タグ・メモのサービス（端末内保存。読み込み前は空）を差し込むための override。
/// 演習の画面（`LearnScreen`）がしおりボタンとメモ欄を出すので、画面を組むテストに入れる。
List<Override> studyNotesTestOverrides() => [
      bookmarkServiceProvider.overrideWithValue(
          BookmarkService(store: SharedPreferencesBookmarkStore('test'))),
      bookmarkTagServiceProvider.overrideWithValue(
          BookmarkTagService(store: SharedPreferencesBookmarkTagStore('test'))),
      questionMemoServiceProvider.overrideWithValue(
          QuestionMemoService(store: SharedPreferencesQuestionMemoStore('test'))),
      // デイリーミッション（演習画面・ホーム・設定が読む）。読み込み前は目標オフ・履歴なし。
      dailyGoalServiceProvider.overrideWithValue(DailyGoalService(store: DailyGoalStore('test'))),
      dailyGoalHistoryServiceProvider
          .overrideWithValue(DailyGoalHistoryService(store: DailyGoalHistoryStore('test'))),
    ];
