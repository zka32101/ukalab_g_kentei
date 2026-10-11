import 'package:flutter/material.dart';
import 'package:ukalab_core/glossary.dart';
import 'package:ukalab_core/ukalab_core.dart';

/// 「用語集」画面（決定50）。検索・分野での絞り込み・「覚えた」チェックは core の
/// [GlossaryListView]。タップで用語カードをボトムシートで開き、関連用語のタップで次の用語に移動する。
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key, required this.exam, required this.terms});

  final ExamConfig exam;
  final List<Term> terms;

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final _store = LearnedTermsStore('g_kentei');

  @override
  Widget build(BuildContext context) {
    return GlossaryListView(
      terms: widget.terms,
      store: _store,
      subjects: {for (final s in widget.exam.subjects) s.subjectId: s.name},
    );
  }
}
