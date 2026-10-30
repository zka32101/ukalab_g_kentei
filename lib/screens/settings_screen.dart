import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart'
    show
        DataManagementSection,
        ExamPrepStrings,
        FileSaver,
        PremiumBenefitsCard,
        PremiumBenefitsStrings,
        historyCsvFileName,
        shareCsv;
import 'package:ukalab_core/ukalab_core.dart'
    show ExamConfig, PremiumFeature, Question, Term, historyCsvText;

import 'package:ukalab_core/cross_promo.dart' show UkalabCrossPromoSection;
import 'package:ukalab_core/daily_goal.dart' show DailyGoalSetting;
import 'package:ukalab_core/reminder.dart' show ReminderSettingsSection;
import 'package:ukalab_core/exam_date.dart';
import '../data/core_features.dart' show isPremiumFor;
import '../data/data_parts.dart';
import '../data/history_store.dart';
import '../widgets/peer_stats_settings_section.dart';
import 'exam_prep_entry.dart';
import 'mistake_note_screen.dart';

/// 本番の applicationId（相互紹介で自アプリを除外するのに使う。ukalab_core の kUkalabAppIds にある値）。
const kCrossPromoAppId = 'com.yourwish.ukalab.g_kentei';

/// 「設定」タブ。課金（決定35）の購入・復元を提供する。広告はnoads/premiumの
/// どちらかを持つと自動的に非表示になる（`AdGate.adsHidden`）。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({
    super.key,
    this.questions = const [],
    this.exam,
    this.terms = const [],
    this.fileSaver,
    this.now,
  });

  /// 履歴CSVの渡し方。null なら core の既定（Web はダウンロード、他は共有シート）。テスト用に差し替える。
  final FileSaver? fileSaver;

  /// CSVのファイル名の日付に使う現在時刻。null なら `DateTime.now`。
  final DateTime Function()? now;

  /// 間違いノートの「解き直す」で演習画面を開くために使う。省略時は間違いノートの入口を出さない。
  final ExamConfig? exam;
  final List<Term> terms;

  /// 履歴CSVの分野集計で、記録に章が無い旧データを補うために使う。
  final List<Question> questions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlement =
        ref.watch(entitlementStateProvider).valueOrNull ?? EntitlementState.free;
    final service = ref.watch(entitlementServiceProvider);
    final handsFree = ref.watch(handsFreeProvider);
    final historyExportUnlocked = isPremiumFor(ref, PremiumFeature.historyExport);

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
        ListTile(
          title: const Text('バージョン'),
          // 実際にインストールされた版（pubspec の version）を読む。
          subtitle: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) =>
                Text(snapshot.hasData ? snapshot.data!.version : ''),
          ),
        ),
        const Divider(height: 24),
        const TextScaleSetting(strings: TextScaleStrings.ja),
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
        Builder(
          builder: (tileContext) => ListTile(
            key: const ValueKey('downloadHistoryCsv'),
            title: const Text('学習履歴をダウンロード（CSV）'),
            // 無料ではロック表示（core の書き出し入口 exportTile と同じ扱い）。
            subtitle: Text(historyExportUnlocked
                ? '日ごと・分野ごとの解答数と正答率。個人情報は含みません。'
                : ExamPrepStrings.ja.premiumNote),
            trailing: historyExportUnlocked ? null : const Icon(Icons.lock_outline),
            onTap: () => historyExportUnlocked
                ? _saveHistory(tileContext, ref)
                : _showPremiumNote(tileContext),
          ),
        ),
        const Divider(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('購入', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        // プレミアム購入者には出さない（広告非表示だけの人には、上位のプレミアムの案内として出す）。
        if (!entitlement.hasPremium) ...[
          PremiumBenefitsCard(strings: _premiumBenefitsStrings),
          const SizedBox(height: 8),
        ],
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
                    _WrapTile(
                      title: offer.title,
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
        const ReminderSettingsSection(),
        // 送信処理が未実装の間は非表示(kPeerStatsSettingsVisible=false)。
        const PeerStatsSettingsSection(),
        const Divider(height: 24),
        DataManagementSection(
          parts: gKenteiDataParts,
          description: '学習進捗・解答履歴・自分用メモは、試験日・ブックマークを除いて、'
              '書き出し・読み込み・リセットができます。',
        ),
        CoreFeatureSettingsTiles(questions: questions),
        if (exam != null)
          ListTile(
            leading: const Icon(Icons.edit_note_outlined),
            title: const Text('間違いノート'),
            subtitle: const Text('間違えた問題を見返して、解き直せます。'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openMistakeNote(context,
                exam: exam!, questions: questions, terms: terms),
          ),
        const Divider(height: 24),
        const _NagaraSettingsTiles(),
        // 掲載リストが空なら何も表示しない。うかラボは大人向けなので保護者ゲートは不要。
        const UkalabCrossPromoSection(currentAppId: kCrossPromoAppId),
      ],
    );
  }

  /// 無料ユーザーがロック中の書き出しを押したとき。保存はせず、プレミアムの案内を出す
  /// （購入欄はこの画面の下にある）。
  void _showPremiumNote(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(ExamPrepStrings.ja.premiumNote)));
  }

  Future<void> _saveHistory(BuildContext context, WidgetRef ref) async {
    final strings = ExamPrepStrings.ja;
    final records = ref.read(historyProvider);
    final messenger = ScaffoldMessenger.of(context);
    String? message;
    if (records.isEmpty) {
      message = 'まだ学習履歴がありません。';
    } else {
      // iPad の共有シートの位置（タイルの矩形）。
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
      try {
        final done = await shareCsv(
          csv: historyCsvText(records, questions),
          fileName: historyCsvFileName((now ?? DateTime.now)()),
          saver: fileSaver,
          sharePositionOrigin: origin,
        );
        if (done) message = strings.exportSaved;
      } catch (_) {
        message = strings.exportSaveFailed;
      }
    }
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
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

/// プレミアムでできること。機能の一覧と説明は core の既定（日本語）で、実装済みの機能だけを載せる。
/// 見出しと「無料の範囲」の一文だけ、このアプリの購入（広告非表示を含む）に合わせる。
final _premiumBenefitsStrings = PremiumBenefitsStrings(
  title: 'プレミアムでできること',
  freeNote: 'プレミアムでは広告も表示されません。問題・解説・模擬試験・基本の苦手特訓は、無料のまま使えます。',
  benefits: PremiumBenefitsStrings.ja.benefits,
);

/// ながらセッションの設定(考える間・次までの間・自動で次へ・解説を読む)。
/// ラベルと候補値は app_common_kit のもの。ながら学習モードのオン/オフとは独立に使える。
class _NagaraSettingsTiles extends ConsumerWidget {
  const _NagaraSettingsTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(handsFreeProvider);
    final notifier = ref.read(handsFreeProvider.notifier);
    final t = KitStrings.of(context).nagara;
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('ながらセッション', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        SwitchListTile(
          title: const Text('解説を読む'),
          subtitle: const Text('ながらセッションで、答えのあとに解説も読み上げます。'),
          value: s.speakExplanation,
          onChanged: notifier.setSpeakExplanation,
        ),
        _SecondsTile(
          key: const ValueKey('nagara-think'),
          title: t.settingsThinkSeconds,
          value: s.thinkSeconds,
          options: HandsFreeSettings.thinkSecondsOptions,
          label: t.secondsOption,
          onChanged: notifier.setThinkSeconds,
        ),
        _SecondsTile(
          key: const ValueKey('nagara-between'),
          title: t.settingsBetweenSeconds,
          value: s.betweenSeconds,
          options: HandsFreeSettings.betweenSecondsOptions,
          label: t.secondsOption,
          onChanged: notifier.setBetweenSeconds,
        ),
        SwitchListTile(
          title: Text(t.settingsAutoAdvance),
          value: s.autoAdvance,
          onChanged: notifier.setAutoAdvance,
        ),
      ],
    );
  }
}

class _SecondsTile extends StatelessWidget {
  const _SecondsTile({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final int value;
  final List<int> options;
  final String Function(int seconds) label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // 保存値が候補にない場合も、いまの値を選択肢に含めて表示を壊さない。
    final items = {...options, value}.toList()..sort();
    return _WrapTile(
      title: title,
      trailing: DropdownButton<int>(
        value: value,
        items: [
          for (final v in items) DropdownMenuItem(value: v, child: Text(label(v))),
        ],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// 見出し＋右端の操作部品（選択欄・ボタン）の行。
///
/// ListTile の trailing だと、文字が大きいとき（端末の最大＋アプリ内「特大」＋小画面）に
/// 操作部品が幅を使い切って見出しが消える。Wrap にして、収まらなければ操作部品を次の行へ送る。
/// 操作部品そのものが画面幅を超えるほど大きいときだけ、収まる分だけ縮める。
class _WrapTile extends StatelessWidget {
  const _WrapTile({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 4,
          children: [
            Text(title, style: Theme.of(context).textTheme.bodyLarge),
            FittedBox(fit: BoxFit.scaleDown, child: trailing),
          ],
        ),
      ),
    );
  }
}
