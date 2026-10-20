import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/reminder.dart';
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_g_kentei/data/exam_repository.dart';
import 'package:ukalab_g_kentei/data/history_store.dart';
import 'package:ukalab_g_kentei/data/progress_store.dart';
import 'package:ukalab_g_kentei/main.dart';

import 'layout_overflow_support.dart';
import 'test_support.dart';

/// 文字切れ・はみ出しの総当たり検査（アプリ全体）。
///
/// 幅 320 / 280dp × 端末の文字倍率 1 / 2 / 3 × アプリ内「文字の大きさ」標準・大・特大で、
/// ホーム・各ラボ・下のタブ・各タブの項目（設定のダイアログ等）を実際に開き、
/// RenderFlex overflow などのレイアウト例外が出ないことを確かめる。
/// 学習を進めた後（記録・間違いノートに中身がある状態）も同じ組で点検する。
///
/// 共有パッケージ（ukalab_core / app_common_kit）が原因の例外は、このリポジトリでは
/// 直せないため失敗にはせず、`SHARED:` として出力する（PR の説明を参照）。

const _sizes = [Size(320, 640), Size(280, 560)];
// 全画面を巡回するので 1 組が重い。端末倍率 × アプリ内の大きさは、標準／中間／最大の 3 組に絞る
// （全 12 組の総当たりは、画面数の少ない text_clipping_content_test.dart で行う）。
const _scaleCombos = [
  (1.0, AppTextScale.standard),
  (2.0, AppTextScale.large),
  (3.0, AppTextScale.xLarge),
];

late ProviderContainer _container;

Future<Widget> _app() async {
  final gate = await testAdGate();
  final reminder = ReminderSettingsService(store: ReminderSettingsStore('test'));
  if (_reminderOff) {
    await reminder.update((s) => s.copyWith(studyReminderEnabled: false, mockReminderEnabled: false));
  }
  _container = ProviderContainer(
    overrides: [
      handsFreeStoreProvider.overrideWithValue(InMemoryHandsFreeStore()),
      ...studyNotesTestOverrides(),
      reminderSettingsServiceProvider.overrideWithValue(reminder),
      coinServiceProvider.overrideWithValue(CoinService(store: InMemoryCoinStore())),
      outfitServiceProvider.overrideWithValue(OutfitService(store: InMemoryOutfitStore())),
      // 購入欄（長い商品名＋価格ボタン）も検査対象にする。
      entitlementServiceProvider.overrideWithValue(FakeEntitlementService(availableOffers: const [
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
      ])),
      adGateProvider.overrideWithValue(gate),
      examStatsServiceProvider.overrideWithValue(FakeExamStatsService()),
    ],
  );
  return UncontrolledProviderScope(container: _container, child: const UkalabGKenteiApp());
}

/// 無限アニメーションがあっても止まらないよう、決まった回数だけ進める。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// 学習リマインダーを切った状態で起動する（共有パッケージの時刻タイルの例外で、
/// 設定画面の自アプリ分の検査が打ち切られないようにする）。
bool _reminderOff = true;

Future<void> _boot(WidgetTester tester) async {
  PackageInfo.setMockInitialValues(
    appName: 'test',
    packageName: 'com.example.test',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: '',
  );
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(() async {
    final app = await _app();
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(app);
    // 問題データ（アセット）の読み込みが終わってタブが出るまで待つ。
    for (var i = 0; i < 100; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(NavigationBar).evaluate().isNotEmpty) break;
    }
  });
  await _settle(tester);
  expect(find.byType(NavigationBar), findsOneWidget, reason: '起動してタブが出ること');
}

Future<bool> _tap(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) return false;
  await tester.ensureVisible(f.first);
  await _settle(tester);
  await tester.tap(f.first, warnIfMissed: false);
  await _settle(tester);
  return true;
}

/// 下のタブが見えるところ（ルート）まで戻る。ダイアログやシートが開いていても閉じる。
Future<void> _back(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    if (find.byType(NavigationBar).evaluate().isNotEmpty &&
        find.byType(ModalBarrier).evaluate().length <= 1) {
      return;
    }
    final nav = tester.state<NavigatorState>(find.byType(Navigator).last);
    if (!nav.canPop()) return;
    nav.pop();
    await _settle(tester);
  }
}

Future<void> _gotoTab(WidgetTester tester, String label) async {
  try {
    await _back(tester);
    await tester.pump(const Duration(milliseconds: 50));
    final nav = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: nav, matching: find.text(label)).first, warnIfMissed: false);
  } catch (_) {
    // 直前の画面のレイアウト例外で木が壊れていても、検査は続ける。
  }
  await _settle(tester);
}

/// 画面を縦に最後までスクロールして、遅延構築されるリストの下の方も組ませる。
Future<void> _scrollAll(WidgetTester tester) async {
  for (var i = 0; i < 14; i++) {
    final s = find.byType(Scrollable).evaluate().where((e) {
      final w = e.widget as Scrollable;
      return w.axisDirection == AxisDirection.down;
    });
    if (s.isEmpty) return;
    await tester.drag(find.byWidget(s.first.widget), const Offset(0, -400), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
  }
  await _settle(tester);
}

/// 「学ぶ」など縦に長い画面で、[f] が組まれるまで下へ送る（見つからなければ例外で気づく）。
Future<void> _scrollToFind(WidgetTester tester, Finder f) async {
  for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
    final sc = find.byType(Scrollable);
    if (sc.evaluate().isEmpty) break;
    await tester.drag(sc.first, const Offset(0, -300), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 30));
  }
  final seen = find
      .byType(Text, skipOffstage: false)
      .evaluate()
      .map((e) => (e.widget as Text).data ?? '')
      .where((t) => t.isNotEmpty)
      .take(40)
      .join(' | ');
  expect(f, findsWidgets, reason: '目的の文言に届くこと。画面の文言: $seen');
}

Future<void> _scrollTop(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) return;
  for (var i = 0; i < 20; i++) {
    await tester.drag(scrollable.first, const Offset(0, 600), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 30));
  }
}

/// 画面の ListTile の見出しを、上から順に集める（遅延構築のリストにも対応）。
Future<List<String>> _tileTitles(WidgetTester tester) async {
  final titles = <String>[];
  void collect() {
    for (final t in tester.widgetList<ListTile>(find.byType(ListTile))) {
      final w = t.title;
      if (w is Text && w.data != null && !titles.contains(w.data)) titles.add(w.data!);
    }
  }

  final scrollable = find.byType(Scrollable);
  if (scrollable.evaluate().isEmpty) return titles;
  for (var i = 0; i < 20; i++) {
    await tester.drag(scrollable.first, const Offset(0, 600), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 30));
  }
  for (var i = 0; i < 20; i++) {
    collect();
    await tester.drag(scrollable.first, const Offset(0, -300), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 30));
  }
  collect();
  return titles;
}

/// 「学ぶ」タブの「道具」（ホームから移った入口）。
const _learnTargets = [
  '間違いノート',
  '用語集',
  '章ごとの解説読み物',
  '用語マップ・AI系譜図',
];

const _homeTargets = [
  '最短ルートプランナー',
  '145問ペース走',
  'AIと法律の境界線',
  '予測→実行',
  '推しの答案を添削',
  '学習の失敗図鑑',
  '評価指標ラボ',
  '手法の選び方',
  '機械学習ラボ',
  '画像認識の中身を見る',
  'Transformerの注意の可視化',
  'ニューラルネット組み立て',
  'AI倫理ケース',
  'AIプロジェクト経営モード',
];

class _Report {
  final app = <String, List<LayoutHit>>{};
  final shared = <String, List<LayoutHit>>{};
  final visited = <String>[];
}

/// 1 つの設定組での総点検。
Future<_Report> _sweep(WidgetTester tester) async {
  final report = _Report();
  final c = LayoutCollector()..start();
  var broken = false;

  Future<void> step(String name, Future<void> Function() body) async {
    if (broken) {
      // 直前の例外で木が壊れた可能性があるので、起動し直してから続ける。
      c.hits.clear();
      await _boot(tester);
      broken = false;
    }
    c.hits.clear();
    report.visited.add(name);
    try {
      await body();
      await _settle(tester);
    } catch (e) {
      // 共有パッケージ側の例外で木が壊れた後の巻き添え（レイアウトされていない描画物）は数えない。
      final cascade = c.hits.isNotEmpty || e.toString().contains('was not laid out');
      if (!cascade) {
        c.hits.add(LayoutHit('TEST-ERROR ${e.toString().split('\n').first}', '?', shared: false));
      }
      broken = true;
    }
    for (final h in c.hits) {
      (h.shared ? report.shared : report.app).putIfAbsent(name, () => []).add(h);
    }
    if (c.hits.any((h) => !h.message.contains('overflowed'))) broken = true;
  }

  try {
    await _boot(tester);
    await step('home', () => _scrollAll(tester));
    await step('home:体験ラボ展開', () async {
      await _tap(tester, find.widgetWithText(HomeSectionHeader, '体験ラボ'));
      await _scrollAll(tester);
    });
    for (final t in _homeTargets) {
      await step('home>$t', () async {
        if (await _tap(tester, find.text(t))) {
          await _scrollAll(tester);
          await _back(tester);
        }
      });
    }
    for (final t in _learnTargets) {
      await step('learn>$t', () async {
        await _gotoTab(tester, '学ぶ');
        await _scrollTop(tester);
        final f = find.text(t);
        await _scrollToFind(tester, f);
        await tester.ensureVisible(f.first);
        await _settle(tester);
        await tester.tap(f.first, warnIfMissed: false);
        await _settle(tester);
        await _scrollAll(tester);
        await _back(tester);
      });
    }
    final labels = tester
        .widgetList<NavigationDestination>(find.byType(NavigationDestination))
        .map((d) => d.label)
        .toList();
    for (final l in labels) {
      await step('tab:$l', () async {
        await _gotoTab(tester, l);
        await _scrollAll(tester);
      });
      await _gotoTab(tester, l);
      final titles = broken ? <String>[] : await _tileTitles(tester);
      for (final t in titles) {
        await step('tab:$l>$t', () async {
          await _gotoTab(tester, l);
          await _scrollTop(tester);
          final f = find.text(t);
          final sc = find.byType(Scrollable).first;
          await tester.scrollUntilVisible(f, 300, scrollable: sc, maxScrolls: 80);
          await tester.tap(f.first, warnIfMissed: false);
          await _settle(tester);
          await _scrollAll(tester);
          await _back(tester);
        });
      }
    }

    // 学習を進めた後（記録・間違いノート・ホームに中身がある状態）。
    if (!broken) {
      await tester.runAsync(() async {
        final data = await _container.read(examDataProvider.future);
        final qs = data.activeQuestions.take(40).toList();
        for (var i = 0; i < qs.length; i++) {
          final ok = i % 3 == 0;
          await _container.read(progressProvider.notifier).recordAnswer(qs[i].qid, correct: ok);
          await _container
              .read(historyProvider.notifier)
              .record(qs[i], correct: ok, ms: 5000, at: DateTime.now());
        }
      });
      await _settle(tester);
    }
    for (final l in labels.where((l) => l == 'ホーム' || l == '記録')) {
      await step('学習後 tab:$l', () async {
        await _gotoTab(tester, l);
        await _scrollAll(tester);
      });
    }
    await step('学習後 learn>間違いノート', () async {
      await _gotoTab(tester, '学ぶ');
      await _scrollTop(tester);
      await _scrollToFind(tester, find.text('間違いノート'));
      if (await _tap(tester, find.text('間違いノート'))) {
        await _scrollAll(tester);
        await _back(tester);
      }
    });
    await step('学習後 tab:記録>実績', () async {
      await _gotoTab(tester, '記録');
      if (await _tap(tester, find.text('実績'))) {
        await _scrollAll(tester);
        await _back(tester);
      }
    });
  } finally {
    c.stop();
  }
  return report;
}

void main() {
  for (final size in _sizes) {
    for (final (sys, app) in _scaleCombos) {
      final name = '${size.width.toInt()}dp 端末×$sys アプリ内${app.name}';
      testWidgets('はみ出しなし: $name', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = sys;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
          appTextScale.value = AppTextScale.standard;
        });
        appTextScale.value = app;
        _reminderOff = true;
        final r = await _sweep(tester);
        for (final e in r.shared.entries) {
          debugPrint('SHARED [$name] ${e.key}: ${e.value.join(' | ')}');
        }
        final msg = r.app.entries.map((e) => '${e.key}: ${e.value.join(' | ')}').join('\n');
        expect(r.app, isEmpty, reason: '\n$msg');
        expect(r.visited.length, greaterThan(25), reason: '画面を十分に巡回できていること');
      }, timeout: const Timeout(Duration(minutes: 6)));
    }
  }

  // 共有パッケージ側の既知の問題（学習リマインダーの時刻タイル）を出力に残すための 1 組。
  // 自アプリ分は失敗にするが、共有パッケージ分は SHARED: として出すだけ。
  testWidgets('共有パッケージの例外の記録（リマインダー有効・280dp 端末×3.0 特大）', (tester) async {
    tester.view.physicalSize = const Size(280, 560);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 3.0;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
      appTextScale.value = AppTextScale.standard;
    });
    appTextScale.value = AppTextScale.xLarge;
    _reminderOff = false;
    final r = await _sweep(tester);
    for (final e in r.shared.entries) {
      debugPrint('SHARED [reminder-on] ${e.key}: ${e.value.join(' | ')}');
    }
    final msg = r.app.entries.map((e) => '${e.key}: ${e.value.join(' | ')}').join('\n');
    expect(r.app, isEmpty, reason: '\n$msg');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
