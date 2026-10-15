import 'package:flutter/material.dart';
import 'package:ukalab_core/ui.dart' show UkalabCertProp, UkalabProps;

/// 資格の小物(G検定は AI・データ系なので `chip`)を小さく添える飾り。
///
/// 装飾なので読み上げ・タップの対象にしない。画像が読めなければ何も出さない(エラーにしない)。
class CertPropBadge extends StatelessWidget {
  const CertPropBadge({
    super.key,
    this.prop = UkalabCertProp.chip,
    this.size = 44,
    this.image,
  });

  final UkalabCertProp prop;
  final double size;

  /// テスト用の差し替え。省略時は ukalab_core の画像。
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: SizedBox(
          width: size,
          height: size,
          child: Image(
            image: image ?? UkalabProps.certImage(prop),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
