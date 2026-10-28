import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/ukalab_core.dart';
import 'package:ukalab_g_kentei/widgets/ai_draft_notice.dart';

const _forbidden = ['公式', '本試験相当', '過去問', '合格保証'];

String _read(String name) => File('assets/experience/$name').readAsStringSync();

void main() {
  final exam = ExamConfig.fromJson(
    jsonDecode(File('assets/exam/g_kentei.json').readAsStringSync()) as Map<String, dynamic>,
  );

  test('story_mode: 検証を通り、5本以上。AI下書きの印は ai-draft の行にだけ付き、由来表記の行は注記対象外', () {
    final text = _read('story_mode_g_kentei.jsonl');
    final parsed = parseStoryScenariosJsonl(text);
    expect(parsed.issues, isEmpty);
    expect(validateStoryScenarios(parsed.scenarios, exam: exam), isEmpty);
    expect(parsed.scenarios.length, greaterThanOrEqualTo(5));
    for (final w in _forbidden) {
      expect(text.contains(w), isFalse, reason: w);
    }
    for (final line in const LineSplitter().convert(text)) {
      if (line.startsWith('{') && line.contains('AI下書き')) {
        final m = jsonDecode(line) as Map<String, dynamic>;
        expect(m['source'], 'original');
        expect(m['sourceRef'], contains('自作'));
        // ai-draft（専門確認前）なら注記が出る。ステータスを外した行は「AI下書き由来」の表記で注記は出ない。
        final ref = m['sourceRef'] as String;
        if (m['contentStatus'] == 'ai-draft') {
          expect(isAiDraftSourceRef(ref), isTrue, reason: ref);
        } else {
          expect(m.containsKey('contentStatus'), isFalse);
          expect(ref, contains('AI下書き由来'));
          expect(isAiDraftSourceRef(ref), isFalse, reason: ref);
        }
      }
    }
  });

  test('AI下書き注記の判定: 専門確認前は出る・由来のみ／下書き表記なしは出ない', () {
    expect(isAiDraftSourceRef('自作（AI下書き・教育用の仮データ）'), isTrue);
    expect(isAiDraftSourceRef('自作（教育用の仮データ。AI下書き由来、体験コンテンツのため専門家確認は不要と判断）'), isFalse);
    expect(isAiDraftSourceRef('自作（教育用の仮データ）'), isFalse);
  });
}
