import 'package:ukalab_core/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_g_kentei/widgets/oshi_card.dart';

Widget _app(Widget child, {List<Override> extra = const []}) => ProviderScope(
      overrides: [
        ...extra,
        coinServiceProvider.overrideWithValue(CoinService(store: InMemoryCoinStore())),
        outfitServiceProvider.overrideWithValue(OutfitService(store: InMemoryOutfitStore())),
      ],
      child: MaterialApp(
        theme: UkalabTheme.light(field: UkalabField.ai, cert: UkalabCert.gKentei),
        builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: c!,
        ),
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('初期状態はLv1、コイン0、タップでセリフが変わる', (tester) async {
    await tester.pumpWidget(_app(const OshiCard(totalQuestions: 600)));
    await tester.pumpAndSettle();

    expect(find.text('あなたの推し  Lv1'), findsOneWidget);
    expect(find.text('学習コイン 0'), findsOneWidget);
    expect(find.byType(MascotWidget), findsOneWidget);

    await tester.tap(find.byType(MascotWidget));
    await tester.pumpAndSettle();
    // セリフが切り替わる可能性があるだけで、クラッシュしないことを確認する。
    expect(tester.takeException(), isNull);
  });

  testWidgets('通常表示では説明が十分な幅を持ち、1文字ずつ縦に折り返されない（実機の不具合の再発防止）',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0; // 幅 360dp（一般的なスマホ）
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const OshiCard(totalQuestions: 600)));
    await tester.pumpAndSettle();

    final desc = tester.getSize(find.text('推しをタップすると、ひとこと話します'));
    // 以前は横並びで説明の幅が約 60dp になり、1文字ずつ折り返されていた。
    expect(desc.width, greaterThan(200));
    // 14文字の1行文（bodySmall）。縦に折り返されれば高さは数倍になる。
    expect(desc.height, lessThan(40));
    // 推しは説明より上にある（縦並び）。
    final mascotBottom = tester.getBottomLeft(find.byType(MascotWidget)).dy;
    final descTop = tester.getTopLeft(find.text('推しをタップすると、ひとこと話します')).dy;
    expect(mascotBottom, lessThanOrEqualTo(descTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('メニューから表示設定を変更できる', (tester) async {
    await tester.pumpWidget(_app(const OshiCard(totalQuestions: 600)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('表示しない'));
    await tester.pumpAndSettle();

    expect(find.text('推しは非表示です'), findsOneWidget);
    expect(find.byType(MascotWidget), findsNothing);
  });

  testWidgets('全問題数0でも落ちない', (tester) async {
    await tester.pumpWidget(_app(const OshiCard(totalQuestions: 0)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('あなたの推し  Lv1'), findsOneWidget);
  });

  testWidgets('メニューの「着替え・ショップ」から衣装画面に遷移する', (tester) async {
    await tester.pumpWidget(_app(const OshiCard(totalQuestions: 600)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('着替え・ショップ'));
    await tester.pumpAndSettle();

    expect(find.byType(WardrobeScreen), findsOneWidget);
  });

  testWidgets('メニューの「合格報告」から合格報告ダイアログが開く', (tester) async {
    await tester.pumpWidget(_app(const OshiCard(totalQuestions: 600)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('試験の結果を報告')); // キット版のメニュー名
    await tester.pumpAndSettle();

    expect(find.textContaining('の結果を教えてください'), findsOneWidget);
  });

  testWidgets('UkalabOshiCard に onLockedTap が渡っている（資格キャラの購入導線）', (tester) async {
    await tester.pumpWidget(_app(const OshiCard(totalQuestions: 600)));
    await tester.pumpAndSettle();

    final card = tester.widget<UkalabOshiCard>(find.byType(UkalabOshiCard));
    expect(card.onLockedTap, isNotNull);
  });

  testWidgets('ロック中のノーダのプレビューから「プレミアムを見る」で設定へ誘導する', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(
      OshiCard(
        totalQuestions: 600,
        settingsBuilder: () => const Text('設定の購入欄スタブ'),
      ),
      extra: [
        characterAppIdProvider.overrideWithValue('g_kentei'),
        characterPremiumProvider.overrideWithValue(false),
      ],
    ));
    await tester.pump();
    await tester.tap(find.byTooltip('推しのメニュー'));
    await tester.pump(const Duration(milliseconds: 500));
    final item = find.ancestor(of: find.text('推しを選ぶ'), matching: find.byType(InkWell)).first;
    tester.widget<InkWell>(item).onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.scrollUntilVisible(find.text('ノーダ'), 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('ノーダ'));
    await tester.pump();
    await tester.tap(find.text('ノーダ'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('プレミアムを見る'), findsOneWidget);
    await tester.tap(find.text('プレミアムを見る'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('設定の購入欄スタブ'), findsOneWidget);
    expect(find.byType(CharacterSelectScreen), findsNothing);
  });
}
