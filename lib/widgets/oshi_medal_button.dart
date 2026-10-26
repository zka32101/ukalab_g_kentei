import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/achievements.dart' show Achievement, achievementsProvider;
import 'package:ukalab_core/ui.dart'
    show
        MascotStage,
        Outfit,
        OshiMedal,
        OshiMedalView,
        equippedOutfitProvider,
        effectiveCharacterPackProvider,
        showOshiMedalDialog;

import '../data/oshi_medals.dart';
import '../data/progress_store.dart';
import '../services/share_card_image.dart' as share_service;
import 'oshi_card.dart' show oshiStageFor;

/// ホームの推しカードの下に置く「メダルを見る・共有」。
/// 連続学習・模擬試験・実績から作ったメダルを選び、共有カードを開く。保存は共有シート経由。
class OshiMedalButton extends ConsumerWidget {
  const OshiMedalButton({
    super.key,
    required this.totalQuestions,
    this.shareImage = share_service.shareCardImage,
    this.now,
  });

  final int totalQuestions;

  /// 画像の共有処理（テストで差し替える）。
  final Future<void> Function(Uint8List png) shareImage;

  /// カードに出す日付（テスト用）。
  final DateTime? now;

  List<OshiMedal> _medals(WidgetRef ref) {
    final progress = ref.read(progressProvider);
    var achievements = const <Achievement>[];
    try {
      achievements = ref.read(achievementsProvider);
    } catch (_) {}
    return buildOshiMedals(
      streakDays: progress.streakDays,
      mockPassed: progress.mockPassedEver,
      achievements: achievements,
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final medals = _medals(ref);
    if (medals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('まだメダルがありません。学習を続けるともらえます')),
      );
      return;
    }
    final picked = await showModalBottomSheet<OshiMedal>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('もらったメダル')),
            for (final m in medals)
              ListTile(
                leading: OshiMedalView(medal: m, size: 40),
                title: Text(m.label),
                onTap: () => Navigator.of(ctx).pop(m),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    final progress = ref.read(progressProvider);
    var stage = MascotStage.lv1;
    try {
      stage = oshiStageFor(
        distinctAnswered: progress.distinctAnswered,
        totalQuestions: totalQuestions,
        correct: progress.correctCount,
      );
    } catch (_) {}
    Outfit? outfit;
    try {
      outfit = ref.read(equippedOutfitProvider);
    } catch (_) {}
    await showOshiMedalDialog(
      context,
      medal: picked,
      pack: ref.read(effectiveCharacterPackProvider),
      stage: stage,
      outfit: outfit,
      now: now,
      onShare: shareImage,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton.icon(
      icon: const Icon(Icons.military_tech_outlined),
      label: const Text('メダルを見る・共有'),
      onPressed: () => _open(context, ref),
    );
  }
}
