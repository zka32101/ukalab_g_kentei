# 休眠中の新形式48問 確認用チェックリスト（優先度つき）

## 1. 目的と注意

- 対象: `assets/questions/g_kentei.jsonl` の g_kentei-0771〜0818（48問）。○×30（0771〜0800）、空欄補充12（0801〜0812）、説明から用語6（0813〜0818）。
- 全問 `ai-draft`（専門家確認前）。人（専門家・運営者）が確認するための優先順位つき一覧であり、正誤の結論はここに書かない。
- 推奨運用: 確認が済むまで `kNewQuestionTypesEnabled` を true にしない。この文書ではコードのフラグは変更しない。
- 既存ルール（`docs/expert_review/README.md`）に従う。
  - `ai-draft` タグは専門家の「OK」が出るまで外さない。
  - 判定が出た問題だけ別PRで反映し、`contentVer` を更新する。
  - 記録するのは確認日（年月）と確認者区分のみ。氏名・所属・連絡先は記録しない。
- 問題の全文は `review_ai_draft.csv` を参照する。この表は id と短い要約のみ。

## 2. 確認の優先度つき一覧

優先度の基準:
- 高: 変化しやすい用語（生成AI、MLOps、ファインチューニング、RAG 等）に関わるもの。
- 中: ○×の限定表現「だけ」型、空欄補充の許容表記の揺れ（12問すべて）、高に近い話題のもの。
- 低: 上記以外。

判定・コメント列は人が記入する（空欄のまま）。

| id | 形式 | 分野(topicId) | 確認の観点 | 優先度 | 判定 | コメント |
|---|---|---|---|---|---|---|
| g_kentei-0771 | ○× | expert_system | エキスパートシステムの定義。要約の妥当性 | 低 |  |  |
| g_kentei-0772 | ○× | generative_ai_terms | 生成AIの定義（「だけ」型の否定文）。変化しやすい用語。限定表現の妥当性 | 高 |  |  |
| g_kentei-0773 | ○× | llm_basics | LLMの説明。要約の妥当性（用語の定義は更新されうる） | 低 |  |  |
| g_kentei-0774 | ○× | supervised_learning | 教師あり学習とラベル（否定文）。要約の妥当性 | 低 |  |  |
| g_kentei-0775 | ○× | unsupervised_learning | 教師なし学習の用途。要約の妥当性 | 低 |  |  |
| g_kentei-0776 | ○× | overfitting | 過学習の定義（誤りの記述）。誤り文の誤りが一意か | 低 |  |  |
| g_kentei-0777 | ○× | cross_validation | 交差検証の手順。要約の妥当性 | 低 |  |  |
| g_kentei-0778 | ○× | reinforcement_learning | 強化学習の説明。要約の妥当性 | 低 |  |  |
| g_kentei-0779 | ○× | backpropagation | 誤差逆伝播法の伝播方向。誤り文の誤りが一意か | 低 |  |  |
| g_kentei-0780 | ○× | gradient_descent | 勾配降下法の説明。要約の妥当性 | 低 |  |  |
| g_kentei-0781 | ○× | loss_function | 損失関数の向き。誤り文の誤りが一意か | 低 |  |  |
| g_kentei-0782 | ○× | activation_relu | ReLUの入出力。誤り文の誤りが一意か | 低 |  |  |
| g_kentei-0783 | ○× | rnn_basics | RNNの目的。誤り文の誤りが一意か | 低 |  |  |
| g_kentei-0784 | ○× | transformer_attention | Transformerとアテンション。要約の妥当性 | 低 |  |  |
| g_kentei-0785 | ○× | mlops | MLOpsの定義（「だけ」型）。変化しやすい用語。限定表現の妥当性 | 高 |  |  |
| g_kentei-0786 | ○× | poc | PoCの説明。要約の妥当性 | 低 |  |  |
| g_kentei-0787 | ○× | bayes_theorem | ベイズの定理の位置づけ。要約の妥当性 | 低 |  |  |
| g_kentei-0788 | ○× | confusion_matrix | 混同行列の説明。要約の妥当性 | 低 |  |  |
| g_kentei-0789 | ○× | normal_distribution | 正規分布の対称性。誤り文の誤りが一意か | 低 |  |  |
| g_kentei-0790 | ○× | p_value | p値の解釈。誤り文の誤りが一意か | 低 |  |  |
| g_kentei-0791 | ○× | xai | XAIの説明。要約の妥当性 | 低 |  |  |
| g_kentei-0792 | ○× | rag_trend | RAGの説明。0808と同じ話題。用語の更新有無 | 中 |  |  |
| g_kentei-0793 | ○× | random_forest | ランダムフォレスト（「だけ」型）。限定表現の妥当性 | 中 |  |  |
| g_kentei-0794 | ○× | knn | kNNの近傍の選び方。誤り文の誤りが一意か | 低 |  |  |
| g_kentei-0795 | ○× | pca | PCAの説明。要約の妥当性（「だけ」型ではない。突合で確認） | 低 |  |  |
| g_kentei-0796 | ○× | clustering | クラスタリングの学習方式。誤り文の誤りが一意か | 低 |  |  |
| g_kentei-0797 | ○× | ensemble_learning | アンサンブル学習の説明。要約の妥当性 | 低 |  |  |
| g_kentei-0798 | ○× | batch_normalization | バッチ正規化の説明。要約の妥当性 | 低 |  |  |
| g_kentei-0799 | ○× | transfer_learning | 転移学習（否定文）。誤り文の誤りが一意か | 低 |  |  |
| g_kentei-0800 | ○× | fine_tuning | ファインチューニング（「だけ」型）。変化しやすい用語。限定表現の妥当性 | 高 |  |  |
| g_kentei-0801 | 空欄補充 | overfitting | 過学習の空欄1。許容表記の揺れ（別表記・略称・英語表記の扱い） | 中 |  |  |
| g_kentei-0802 | 空欄補充 | supervised_learning | 教師あり学習の空欄1。許容表記の揺れ（別表記・略称・英語表記の扱い） | 中 |  |  |
| g_kentei-0803 | 空欄補充 | reinforcement_learning | 強化学習の空欄1。許容表記の揺れ（別表記・略称・英語表記の扱い） | 中 |  |  |
| g_kentei-0804 | 空欄補充 | gradient_descent | 勾配降下法の空欄2つ。許容表記の揺れ（別表記・略称・英語表記の扱い） | 中 |  |  |
| g_kentei-0805 | 空欄補充 | confusion_matrix | 混同行列の指標。英語表記を含む。許容表記の揺れ（別表記・略称・英語表記の扱い） | 中 |  |  |
| g_kentei-0806 | 空欄補充 | normal_distribution | 正規分布の空欄1。許容表記の揺れ（別表記・略称・英語表記の扱い） | 中 |  |  |
| g_kentei-0807 | 空欄補充 | bayes_theorem | ベイズの定理の空欄2つ。許容表記の揺れ（別表記・略称・英語表記の扱い） | 中 |  |  |
| g_kentei-0808 | 空欄補充 | rag_trend | RAGの空欄1。変化しやすい用語。許容表記の揺れ（別表記・略称・英語表記の扱い）。変化しやすい用語 | 高 |  |  |
| g_kentei-0809 | 空欄補充 | pca | PCAの空欄1。許容表記の揺れ（別表記・略称・英語表記の扱い） | 中 |  |  |
| g_kentei-0810 | 空欄補充 | p_value | p値の空欄1。許容表記の揺れ（別表記・略称・英語表記の扱い） | 中 |  |  |
| g_kentei-0811 | 空欄補充 | random_forest | ランダムフォレストの空欄1。許容表記の揺れ（別表記・略称・英語表記の扱い） | 中 |  |  |
| g_kentei-0812 | 空欄補充 | transformer_attention | Transformerの空欄1。許容表記の揺れ（別表記・略称・英語表記の扱い） | 中 |  |  |
| g_kentei-0813 | 説明から用語 | transfer_learning | 説明文から用語を選ぶ（転移学習）。説明文の妥当性・別表記の扱い | 低 |  |  |
| g_kentei-0814 | 説明から用語 | cross_validation | 説明文から用語を選ぶ（交差検証）。説明文の妥当性・別表記の扱い | 低 |  |  |
| g_kentei-0815 | 説明から用語 | confusion_matrix | 説明文から用語を選ぶ（混同行列）。説明文の妥当性・別表記の扱い | 低 |  |  |
| g_kentei-0816 | 説明から用語 | activation_relu | 説明文から用語を選ぶ（ReLU）。説明文の妥当性・別表記の扱い | 低 |  |  |
| g_kentei-0817 | 説明から用語 | knn | 説明文から用語を選ぶ（k近傍法）。説明文の妥当性・別表記の扱い | 低 |  |  |
| g_kentei-0818 | 説明から用語 | ensemble_learning | 説明文から用語を選ぶ（アンサンブル学習）。説明文の妥当性・別表記の扱い | 低 |  |  |

件数: 高 4 / 中 13 / 低 31（計 48）。

## 3. 法律・時事（lawVersion 付き）

新形式の48問（0771〜0818）に `lawVersion` を持つ問題はない（jsonl で再確認済み）。`lawVersion` 付きの既存問題は 0771 より前のみ。

## 4. 確認後の手順

1. 判定が OK の問題を確定する（修正・削除は内容を反映する）。
2. `ai-draft` タグを外す PR を別に作る（OK の問題のみ）。
3. 反映時に `contentVer` を更新する。
4. `kNewQuestionTypesEnabled` の扱いは別途決定する（この文書では変更しない）。
