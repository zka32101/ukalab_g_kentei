import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/ukalab_core.dart';

const _forbidden = ['公式', '本試験相当', '過去問', '合格保証'];

String _read(String name) => File('assets/experience/$name').readAsStringSync();

void main() {
  final exam = ExamConfig.fromJson(
    jsonDecode(File('assets/exam/g_kentei.json').readAsStringSync()) as Map<String, dynamic>,
  );

  test('story_mode: 検証を通り、5本以上で AI下書きの印がある', () {
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
        expect(m['contentStatus'], 'ai-draft');
        expect(m['source'], 'original');
        expect(m['sourceRef'], contains('自作'));
      }
    }
  });
}
