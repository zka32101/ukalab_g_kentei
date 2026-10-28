import 'package:flutter/material.dart';

/// AI下書きの体験型教材（シナリオ・ケース）を開いたときに出す注記。
/// 専門確認が済む、または体験コンテンツで専門家確認不要と判断して `contentStatus` を外した行は、
/// `sourceRef` が「AI下書き由来」の表記になり、表示されなくなる。
const String kAiDraftScenarioNotice = '学習用の架空シナリオ（AI下書き・専門確認前）';

/// [sourceRef] が AI下書き（専門確認前）を示すか。
/// 「AI下書き由来」（由来の記録のみ。確認不要と判断済み）は下書き扱いにしない。
bool isAiDraftSourceRef(String sourceRef) =>
    sourceRef.contains('AI下書き') && !sourceRef.contains('AI下書き由来');

class AiDraftNotice extends StatelessWidget {
  const AiDraftNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        kAiDraftScenarioNotice,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
