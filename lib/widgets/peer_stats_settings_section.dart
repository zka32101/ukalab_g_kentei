import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/peer_stats_prep.dart';

/// 仲間集計への参加スイッチを設定画面に出すか。
///
/// 送る側(送信処理)がまだ存在しない間は、スイッチを見せると「送っている/いない」の
/// 誤解を招くので false。送信を実装・接続する PR で true にする。
const bool kPeerStatsSettingsVisible = false;

/// 「匿名の仲間集計に参加する」スイッチ(説明文付き)。既定OFF。
class PeerStatsSettingsSection extends ConsumerStatefulWidget {
  const PeerStatsSettingsSection({super.key, this.visible = kPeerStatsSettingsVisible});

  /// テストでだけ true にして表示を確かめる。本番は [kPeerStatsSettingsVisible]。
  final bool visible;

  @override
  ConsumerState<PeerStatsSettingsSection> createState() => _PeerStatsSettingsSectionState();
}

class _PeerStatsSettingsSectionState extends ConsumerState<PeerStatsSettingsSection> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    if (widget.visible) _load();
  }

  Future<void> _load() async {
    final v = await ref.read(peerStatsSettingsProvider).isSharingEnabled();
    if (mounted) setState(() => _enabled = v);
  }

  Future<void> _set(bool v) async {
    setState(() => _enabled = v);
    await ref.read(peerStatsSettingsProvider).setSharingEnabled(v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('匿名の仲間集計に参加する'),
          subtitle: const Text(
            '1日1回、次の値だけを匿名で送ります: 連続学習日数・累計の問題数・試験日。'
            '名前・メール・端末を特定できる情報は送りません。\n'
            '参加しなくても、みんなの集計は見られます。いつでもオフにできます。',
          ),
          isThreeLine: true,
          value: _enabled,
          onChanged: _set,
        ),
        const Divider(height: 1),
      ],
    );
  }
}
