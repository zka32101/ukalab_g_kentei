import 'package:app_common_kit/app_common_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ukalab_core/ui.dart';

import 'package:ukalab_g_kentei/data/character_wiring.dart';

ProviderContainer _container(bool premium) {
  final c = ProviderContainer(overrides: [
    entitlementStateProvider
        .overrideWith((ref) => Stream.value(EntitlementState(hasPremium: premium))),
    ...characterOverrides,
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('appId は g_kentei', () {
    expect(_container(false).read(characterAppIdProvider), 'g_kentei');
  });

  test('無料は false', () async {
    final c = _container(false);
    await c.read(entitlementStateProvider.future);
    expect(c.read(characterPremiumProvider), isFalse);
  });

  test('プレミアムは true', () async {
    final c = _container(true);
    await c.read(entitlementStateProvider.future);
    expect(c.read(characterPremiumProvider), isTrue);
  });
}
