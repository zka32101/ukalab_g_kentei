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

  test('ethics_case: 検証を通り、4件以上。追加データに AI下書きの印がある', () {
    final text = _read('ethics_case_g_kentei.jsonl');
    final parsed = parseEthicsCaseScenariosJsonl(text);
    expect(parsed.issues, isEmpty);
    expect(validateEthicsCaseScenarios(parsed.scenarios, exam: exam), isEmpty);
    expect(parsed.scenarios.length, greaterThanOrEqualTo(4));
    for (final f in const [
      'ethics_case_g_kentei.jsonl',
      'ml_lab_g_kentei.jsonl',
      'nn_builder_g_kentei.jsonl',
      'conv_lab_g_kentei.jsonl',
    ]) {
      final t = _read(f);
      for (final w in _forbidden) {
        expect(t.contains(w), isFalse, reason: '$f $w');
      }
      for (final line in const LineSplitter().convert(t)) {
        if (line.startsWith('{') && line.contains('AI下書き')) {
          final m = jsonDecode(line) as Map<String, dynamic>;
          expect(m['contentStatus'], 'ai-draft');
          expect(m['source'], 'original');
        }
      }
    }
  });
}
