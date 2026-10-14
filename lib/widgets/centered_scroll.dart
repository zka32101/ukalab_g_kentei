import 'package:flutter/material.dart';

/// 中央寄せの案内画面（導入・結果・空状態）を、文字が大きくなっても切れないようにする枠。
///
/// 内容が画面に収まるときは従来どおり縦中央に置き、収まらないとき（端末の文字サイズ最大・
/// アプリ内「特大」・小さな画面が重なったとき）は縦にスクロールできるようにして、
/// RenderFlex の下方向のはみ出し（文言が見えなくなる）を防ぐ。
class CenteredScroll extends StatelessWidget {
  const CenteredScroll({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight =
            (constraints.maxHeight - padding.vertical).clamp(0.0, double.infinity);
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
