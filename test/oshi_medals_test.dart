import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ukalab_core/achievements.dart' show Achievement, achievementsProvider;
import 'package:ukalab_core/ui.dart';
import 'package:ukalab_g_kentei/data/oshi_medals.dart';
import 'package:ukalab_g_kentei/data/progress_store.dart';
import 'package:ukalab_g_kentei/services/share_card_image.dart';
import 'package:ukalab_g_kentei/widgets/oshi_medal_button.dart';

class _FakeProgress extends ProgressNotifier {
  _FakeProgress(this._state);
  final ProgressState _state;
  @override
  ProgressState build() => _state;
}

Achievement _ach(String id, String title, {bool unlocked = true}) =>
    Achievement(id: id, title: title, description: 'd', icon: Icons.star, unlocked: unlocked);

void main() {
  group('buildOshiMedals', () {
    test('何も無ければメダルは空', () {
      expect(buildOshiMedals(streakDays: 6, mockPassed: false), isEmpty);
    });

    test('連続学習は到達した最大の節目だけ（7=銅・30=銀・100=金）', () {
      OshiMedal one(int d) => buildOshiMedals(streakDays: d, mockPassed: false).single;
      expect(one(7).tier, 1);
      expect(one(7).id, 'streak_7');
      expect(one(29).id, 'streak_7');
      expect(one(30).tier, 2);
      expect(one(99).id, 'streak_30');
      expect(one(100).tier, 3);
      expect(one(365).id, 'streak_100');
      expect(one(7).kind, OshiMedalKind.streak);
    });

    test('模擬試験の合格と、解除済みの実績だけがメダルになる', () {
      final medals = buildOshiMedals(
        streakDays: 0,
        mockPassed: true,
        achievements: [_ach('a1', '最初の一歩'), _ach('a2', '未解除', unlocked: false)],
      );
      expect(medals.map((m) => m.id), ['mock_pass', 'achievement_a1']);
      expect(medals.first.kind, OshiMedalKind.mockPass);
      expect(medals.last.label, '最初の一歩');
      expect(medals.every((m) => m.image == null), isTrue); // コード描画
    });
  });

  group('shareCardImage', () {
    final png = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47]);

    test('共有できればダウンロードしない', () async {
      var downloaded = 0;
      ShareParams? sent;
      await shareCardImage(
        png,
        isWeb: true,
        share: (p) async {
          sent = p;
          return const ShareResult('ok', ShareResultStatus.success);
        },
        download: (_, __) => downloaded++,
      );
      expect(downloaded, 0);
      expect(sent!.files, hasLength(1));
      expect(sent!.downloadFallbackEnabled, isFalse);
      expect(sent!.files!.single.mimeType, 'image/png');
    });

    test('Web で共有に成功した結果が unavailable でもダウンロードしない（共有成功時の二重保存を防ぐ）', () async {
      var downloaded = 0;
      await shareCardImage(
        png,
        isWeb: true,
        share: (_) async => ShareResult.unavailable,
        download: (_, __) => downloaded++,
      );
      expect(downloaded, 0);
    });

    test('Web で共有が例外を投げてもダウンロードにフォールバック', () async {
      var downloaded = 0;
      await shareCardImage(
        png,
        isWeb: true,
        share: (_) async => throw UnsupportedError('no share'),
        download: (_, n) {
          downloaded++;
          expect(n, endsWith('.png'));
        },
      );
      expect(downloaded, 1);
    });

    test('ネイティブでは例外を隠さず、ダウンロードもしない', () async {
      var downloaded = 0;
      await expectLater(
        shareCardImage(
          png,
          isWeb: false,
          share: (_) async => throw StateError('fail'),
          download: (_, __) => downloaded++,
        ),
        throwsStateError,
      );
      expect(downloaded, 0);
    });
  });

  group('OshiMedalButton', () {
    Future<void> pump(
      WidgetTester tester, {
      required ProgressState progress,
      List<Achievement> achievements = const [],
      Future<void> Function(Uint8List)? onShare,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          progressProvider.overrideWith(() => _FakeProgress(progress)),
          achievementsProvider.overrideWithValue(achievements),
          coinServiceProvider.overrideWithValue(CoinService(store: InMemoryCoinStore())),
          outfitServiceProvider.overrideWithValue(OutfitService(store: InMemoryOutfitStore())),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OshiMedalButton(
              totalQuestions: 600,
              now: DateTime(2026, 10, 13),
              shareImage: onShare ?? (_) async {},
            ),
          ),
        ),
      ));
    }

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('メダルが無いときは案内だけ出してダイアログは開かない', (tester) async {
      await pump(tester, progress: const ProgressState());
      await tester.tap(find.text('メダルを見る・共有'));
      await settle(tester);
      expect(find.text('まだメダルがありません。学習を続けるともらえます'), findsOneWidget);
      expect(find.byType(OshiMedalShareCard), findsNothing);
    });

    testWidgets('一覧から選ぶと共有カードが開き、共有で PNG が渡る', (tester) async {
      Uint8List? shared;
      await pump(
        tester,
        progress: const ProgressState(streakDays: 8, mockPassedEver: true),
        achievements: [_ach('a1', '最初の一歩')],
        onShare: (p) async => shared = p,
      );
      await tester.tap(find.text('メダルを見る・共有'));
      await settle(tester);
      expect(find.text('7日連続で学習'), findsOneWidget);
      expect(find.text('模擬試験で目安の正答率を超えた'), findsOneWidget);
      expect(find.text('最初の一歩'), findsOneWidget);

      await tester.tap(find.text('7日連続で学習'));
      await settle(tester);
      expect(find.byType(OshiMedalShareCard), findsOneWidget);
      expect(find.textContaining('個人情報は入りません'), findsOneWidget);
      expect(find.text('画像を保存'), findsNothing); // 保存は共有シート経由（専用保存は作らない）

      await tester.runAsync(() async {
        await tester.tap(find.text('共有する'));
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump();
      });
      expect(shared, isNotNull);
      expect(shared!.sublist(1, 4), [0x50, 0x4E, 0x47]);
    });
  });
}
