# 相互紹介（クロスプロモ）

うかラボ8アプリの相互紹介。`cross_promo_kit` を、`ukalab_core` の薄いラッパー（`package:ukalab_core/cross_promo.dart`）経由で使う。独自実装はしない。

## このアプリでの使い方

- applicationId: `com.yourwish.ukalab.g_kentei`（`lib/screens/settings_screen.dart` の `kCrossPromoAppId`。`kUkalabAppIds` にある値）
- 初期化: `lib/main.dart` で `unawaited(UkalabCrossPromo.init())`。Firebase 初期化と Remote Config 取得をまとめて行い、失敗しても例外を投げず、起動を止めない。
- 表示: 設定タブの最下部に `UkalabCrossPromoSection(currentAppId: kCrossPromoAppId)`。掲載が0件なら何も表示しない。自アプリは一覧から除外される。
- 対象: 大人向けの資格アプリなので `isChildDirected` は既定の `false`（保護者ゲートなし）。問題・模擬試験・復習の画面には置かない。
- 広告との関係: 自社アプリの案内であり広告ではない。広告非表示の購入者にも表示される（方針は運営判断）。

## Remote Config

- キー: `cross_promo_apps`（値は JSON 配列。未設定は `[]`）
- カテゴリ: `うかラボ`（同じカテゴリのアプリ同士で紹介する）
- 項目: `id`（applicationId）/ `name` / `tagline` / `iconUrl` / `storeUrl` / `category`
- 例（値はプレースホルダ）:

```json
[
  {
    "id": "<applicationId>",
    "name": "<アプリ名>",
    "tagline": "<ひとこと説明>",
    "iconUrl": "<アイコン画像のURL>",
    "storeUrl": "<ストアページのURL>",
    "category": "うかラボ"
  }
]
```

- 掲載リストの正・検証・投入手順は `cross_promo_kit` の `docs/ROLLOUT.md` と `docs/cross_promo_apps.json` を参照。公開を確認したアプリだけを載せ、Firebase プロジェクトごとに同じ内容を投入する。
- Firebase 設定ファイル（`google-services.json`）の注入は `docs/release_prep_log.md` を参照。

## テスト

`test/cross_promo_test.dart` と `test/settings_screen_test.dart`。Firebase 未初期化・掲載0件で、何も表示せず例外にならないことを確認する。
