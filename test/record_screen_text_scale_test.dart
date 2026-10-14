import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_g_kentei/data/progress_store.dart';
import 'package:ukalab_g_kentei/screens/record_screen.dart';

Question _q(String qid) => Question(
      qid: qid,
      examId: 'g_kentei',
      subjectId: 's1',
      topicId: 't',
      prompt: 'p',
      choices: const ['a', 'b'],
      answerIndex: 0,
      explanation: 'e',
      source: QuestionSource.original,
      sourceRef: '自作',
      contentVer: '1',
    );

Future<void> _pump(WidgetTester tester, {required double scale, required bool answered}) async {
  tester.view.physicalSize = const Size(280, 560);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAllTestValues();
  });
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: Scaffold(body: RecordScreen(questions: [_q('a'), _q('b')]))),
  ));
  await tester.pump();
  if (answered) {
    await container.read(progressProvider.notifier).recordAnswer('a', correct: true);
    await container.read(progressProvider.notifier).recordAnswer('b', correct: false);
    await tester.pump();
  }
}

void main() {
  testWidgets('文字が大きくても、数字カードの数字が 1 文字ずつ折り返されない', (tester) async {
    await _pump(tester, scale: 3.0, answered: true);
    // 'N問' は 1 行（高さが文字の高さの 1.5 倍未満）で出る。
    final lineHeight = tester.getSize(find.text('2問')).height;
    final fontSize = Theme.of(tester.element(find.text('2問'))).textTheme.titleLarge!.fontSize!;
    expect(lineHeight, lessThan(fontSize * 3.0 * 1.5), reason: '"2問" が複数行に割れている');
    expect(tester.takeException(), isNull);
  });

  testWidgets('通常の文字サイズでは、3 枚を横に並べる（従来どおり）', (tester) async {
    await _pump(tester, scale: 1.0, answered: true);
    // Row の既定は縦中央ぞろえなので、カードの縦の中心が揃っていれば同じ行に並んでいる。
    Offset card(String label) => tester.getCenter(
        find.ancestor(of: find.text(label), matching: find.byType(Card)).first);
    final a = card('解いた問題');
    final b = card('正答率');
    final c = card('連続学習');
    expect(a.dy, b.dy, reason: '同じ高さに並ぶ');
    expect(b.dy, c.dy, reason: '同じ高さに並ぶ');
    expect(a.dx, lessThan(b.dx));
    expect(b.dx, lessThan(c.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('空の案内は、文字が最大でも切れずにスクロールで読める', (tester) async {
    await _pump(tester, scale: 3.0, answered: false);
    expect(find.textContaining('学習の記録はこれから'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
