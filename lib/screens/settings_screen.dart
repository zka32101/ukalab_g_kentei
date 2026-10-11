import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart' show DataManagementSection;
import 'package:ukalab_core/ukalab_core.dart' show Question, historyCsv;

import 'package:ukalab_core/daily_goal.dart' show DailyGoalSetting;
import 'package:ukalab_core/exam_date.dart';
import '../data/data_parts.dart';
import '../data/history_store.dart';

/// 「設定」タブ。課金（決定35）の購入・復元を提供する。広告はnoads/premiumの
/// どちらかを持つと自動的に非表示になる（`AdGate.adsHidden`）。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.questions = const []});

  /// 履歴CSVの分野集計で、記録に章が無い旧データを補うために使う。
  final List<Question> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement =
        ref.watch(entitlementStateProvider).valueOrNull ?? EntitlementState.free;
    final service = ref.watch(entitlementServiceProvider);
    final handsFree = ref.watch(handsFreeProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ListTile(
          title: Text('このアプリについて'),
          subtitle: Text(
            '「うかラボ G検定」は、一般社団法人日本ディープラーニング協会（JDLA）とは'
            '無関係に開発・運営する非公式の学習アプリです。問題はすべて独自に作成しています。',
          ),
        ),
        const Divider(height: 1),
        const ListTile(
          title: Text('バージョン'),
          subtitle: Text('0.1.0'),
        ),
        const Divider(height: 24),
        SwitchListTile(
          title: const Text('ながら学習モード'),
          subtitle: const Text('大きな選択肢ボタンで、問題を読み上げます。'),
          value: handsFree.enabled,
          onChanged: (v) => ref.read(handsFreeProvider.notifier).setEnabled(v),
        ),
        if (handsFree.enabled)
          SwitchListTile(
            title: const Text('問題を読み上げる'),
            value: handsFree.speakQuestion,
            onChanged: (v) => ref.read(handsFreeProvider.notifier).setSpeakQuestion(v),
          ),
        ExamDateTile(
          date: ref.watch(examDateProvider),
          onChanged: (d) => ref.read(examDateProvider.notifier).setDate(d),
        ),
        ListTile(
          title: const Text('学習履歴をコピー（CSV）'),
          subtitle: const Text('日ごと・分野ごとの解答数と正答率。個人情報は含みません。'),
          onTap: () => _copyHistory(context, ref),
        ),
        const Divider(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('購入', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        if (entitlement.adsHidden)
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: Text(entitlement.hasPremium ? 'プレミアムを購入済みです' : '広告非表示を購入済みです'),
          )
        else
          FutureBuilder<List<EntitlementOffer>>(
            future: service.offers(),
            builder: (context, snapshot) {
              final offers = snapshot.data ?? const [];
              if (offers.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  for (final offer in offers)
                    ListTile(
                      title: Text(offer.title),
                      trailing: FilledButton(
                        onPressed: () => _purchase(context, ref, offer),
                        child: Text(offer.priceString),
                      ),
                    ),
                ],
              );
            },
          ),
        TextButton(
          onPressed: () => _restore(context, ref),
          child: const Text('購入を復元'),
        ),
        const Divider(height: 24),
        const DailyGoalSetting(),
        const Divider(height: 24),
        DataManagementSection(
          parts: gKenteiDataParts,
          description: '学習進捗・解答履歴・自分用メモは、試験日・ブックマークを除いて、'
              '書き出し・読み込み・リセットができます。',
        ),
      ],
    );
  }

  Future<void> _copyHistory(BuildContext context, WidgetRef ref) async {
    final records = ref.read(historyProvider);
    final message = records.isEmpty ? 'まだ学習履歴がありません。' : '学習履歴をコピーしました。';
    if (records.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: historyCsv(records, questions)));
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _purchase(BuildContext context, WidgetRef ref, EntitlementOffer offer) async {
    final outcome = await ref.read(entitlementServiceProvider).purchaseOffer(offer.id);
    if (!context.mounted) return;
    final message = switch (outcome) {
      PurchaseOutcome.success => '購入しました。',
      PurchaseOutcome.cancelled => '購入をキャンセルしました。',
      PurchaseOutcome.blockedByGate => '購入できませんでした。',
      PurchaseOutcome.failed => '購入に失敗しました。',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final state = await ref.read(entitlementServiceProvider).restore();
    if (!context.mounted) return;
    final message = state.adsHidden ? '購入を復元しました。' : '復元できる購入がありませんでした。';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
