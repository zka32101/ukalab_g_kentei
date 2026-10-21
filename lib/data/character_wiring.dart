import 'package:app_common_kit/app_common_kit.dart' show EntitlementState, entitlementStateProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ukalab_core/ui.dart' show characterAppIdProvider, characterPremiumProvider;

/// 資格専用キャラ（ノーダ）のための、このアプリのID。ukalab_core の `appIds` と同じ綴り。
const kCharacterAppId = 'g_kentei';

/// 資格専用キャラの出し分けに必要な override。
/// プレミアムかどうかは権利状態（entitlementStateProvider）に追従する。
final List<Override> characterOverrides = [
  characterAppIdProvider.overrideWithValue(kCharacterAppId),
  characterPremiumProvider.overrideWith(
    (ref) => (ref.watch(entitlementStateProvider).valueOrNull ?? EntitlementState.free).hasPremium,
  ),
];
