import 'package:flutter/material.dart';

/// AI下書きの体験型教材（シナリオ・ケース）を開いたときに出す注記。
/// 専門確認が済んで `sourceRef` から「AI下書き」が外れると表示されなくなる。
const String kAiDraftScenarioNotice = '学習用の架空シナリオ（AI下書き・専門確認前）';

/// [sourceRef] が AI下書きを示すか。
bool isAiDraftSourceRef(String sourceRef) => sourceRef.contains('AI下書き');

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
