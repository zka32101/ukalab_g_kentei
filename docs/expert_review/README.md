# 専門家レビュー対象（AI下書き・未確認）

- **確認済み（2026-10-28）**: 問題データ（`assets/questions/g_kentei.jsonl`）の ai-draft 問題 148問（g_kentei-0711〜0858）は専門家確認OKとなり、`ai-draft` タグを外した（`sourceRef` は「専門家確認済み」に更新、`contentVer` は 2026.10.28）。下の対象数・運用ルールは確認前の記録。体験型（`assets/experience/`）の `contentStatus: ai-draft` は本件の対象外だった。
- **体験コンテンツの扱い（2026-10-28）**: 体験コンテンツ10本（story_mode 4・ethics_case 3・conv_lab/ml_lab/nn_builder 各1）は「あくまで体験なので専門家確認は不要」と運営者が判断し、`contentStatus: ai-draft` を外した（`contentVer` 2026.10.28、本文は変更なし）。**専門家の確認は行っていない**ため「専門家確認済み」とは書かない。`sourceRef` は「自作（教育用の仮データ。AI下書き由来、体験コンテンツのため専門家確認は不要と判断）」として由来を残し、画面の「AI下書き・専門確認前」注記は出なくなる（注記は `sourceRef` に「AI下書き由来」を含まない「AI下書き」表記の行にだけ出る）。以後の体験コンテンツ追加分は従来どおり ai-draft から始める。

- 対象: ai-draft 問題 108問（g_kentei-0711〜0818。0771〜0818 は新形式の○×30・空欄補充12・説明から用語6）
- 新形式の行: 「問題文」末尾に形式名を付記。○×は正解列に○/×、空欄補充は選択肢列に各空欄の候補・正解列に空欄ごとの正解（/ は許容表記）、説明から用語は問題文に説明文
- 必要な専門性: G検定合格者・AI/機械学習の実務者
- 一覧: `review_ai_draft.csv`（UTF-8 BOM付き。Excel で開ける。末尾3列「判定(OK/修正/削除)」「コメント」「根拠」は空欄）
- 依頼文・確認観点・反映方法・範囲外事項: ukalab_core の `docs/expert_review_requests.md` と `docs/expert_review_session_handover.md`

## 運用ルール
- `ai-draft` タグは専門家の「OK」が出るまで外さない。広告表現（別の観点で出題 等）の根拠にも数えない。
- 判定が出た問題だけ別PRで反映（`contentVer` 更新）。「OK」のみタグを外す。「削除」は `disabled: true` か行削除。
- 記録するのは確認日（年月）と確認者区分のみ。氏名・所属・連絡先は記録しない。
- CSV の再生成: `python3 <core>/tools/export_review_csv.py <jsonl> --tag ai-draft -o docs/expert_review/review_ai_draft.csv`
