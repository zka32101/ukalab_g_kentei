import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ui.dart' show PeerStatsCard;
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_g_kentei/data/peer_stats_prep.dart';
import 'package:ukalab_g_kentei/data/progress_store.dart';
import 'package:ukalab_g_kentei/widgets/cert_prop_badge.dart';
import 'package:ukalab_g_kentei/widgets/peer_stats_settings_section.dart';

class _BrokenImage extends ImageProvider<_BrokenImage> {
  @override
  Future<_BrokenImage> obtainKey(ImageConfiguration c) => Future.value(this);
  @override
  ImageStreamCompleter loadImage(_BrokenImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Future<ImageInfo>.error(Exception('broken')));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('PeerStatsSettings', () {
    test('既定はOFF、保存と復元ができる', () async {
      const s = SharedPreferencesPeerStatsSettings();
      expect(await s.isSharingEnabled(), isFalse);
      await s.setSharingEnabled(true);
      expect(await const SharedPreferencesPeerStatsSettings().isSharingEnabled(), isTrue);
      await s.setSharingEnabled(false);
      expect(await s.isSharingEnabled(), isFalse);
    });
  });

  group('ローカル値の取り出し', () {
    test('既存の値と一致する', () {
      const progress = ProgressState(
        answeredQidToCorrect: {'a': true, 'b': false, 'c': true},
        streakDays: 5,
      );
      expect(peerStreakDays(progress), 5);
      expect(peerDistinctQuestionCount(progress), progress.distinctAnswered);
      expect(peerDistinctQuestionCount(progress), 3);
      expect(peerExamDateKey(DateTime(2026, 11, 21)), '2026-11-21');
      expect(peerExamDateKey(null), isNull);
    });

    test('延べ回答数は履歴の件数', () {
      final r = ProgressRecord(qid: 'a', subjectId: 's', correct: true, at: DateTime(2026, 1, 1));
      expect(peerTotalAnsweredCount([r, r, r]), 3);
      expect(peerTotalAnsweredCount(const []), 0);
    });
  });

  group('設定スイッチ', () {
    Widget app({bool? visible}) => ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: visible == null
                  ? const PeerStatsSettingsSection()
                  : PeerStatsSettingsSection(visible: visible),
            ),
          ),
        );

    test('本番の既定フラグは非表示', () => expect(kPeerStatsSettingsVisible, isFalse));

    testWidgets('既定(本番フラグ)では何も出ない', (tester) async {
      await tester.pumpWidget(app());
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('有効時だけ表示され、既定OFFで、切り替えが保存される', (tester) async {
      await tester.pumpWidget(app(visible: true));
      await tester.pumpAndSettle();
      expect(find.text('匿名の仲間集計に参加する'), findsOneWidget);
      expect(find.textContaining('参加しなくても'), findsOneWidget);
      expect(find.textContaining('連続学習日数'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isFalse);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(await const SharedPreferencesPeerStatsSettings().isSharingEnabled(), isTrue);
    });
  });

  group('PeerStatsCard(モック)', () {
    testWidgets('モックの集計を表示する', (tester) async {
      const snap = PeerStatsSnapshot(
        asOf: '2026-10-15',
        activeToday: 1234,
        participants: 500,
        totalQuestions: 100000,
        medianQuestions: 200,
      );
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: PeerStatsCard(snapshot: snap, strings: null)),
      ));
      expect(find.textContaining('1,234'), findsOneWidget);
      expect(find.textContaining('100,000'), findsOneWidget);
    });
  });

  group('CertPropBadge', () {
    testWidgets('小さい幅でもあふれず表示される', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(children: [
            const Expanded(child: Text('うかラボ G検定 とても長い見出しの文字列がここに入ります')),
            CertPropBadge(image: MemoryImage(_png)),
          ]),
        ),
      ));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('画像の読込に失敗しても例外にせず非表示', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: CertPropBadge(image: _BrokenImage())),
      ));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
    });
  });
}

// 1x1 の透明PNG。
final Uint8List _png = Uint8List.fromList(const [
  137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0,
  0, 31, 21, 196, 137, 0, 0, 0, 13, 73, 68, 65, 84, 120, 156, 99, 248, 255, 255, 63, 0, 5, 254, 2,
  254, 167, 53, 129, 132, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);
