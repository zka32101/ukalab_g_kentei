# 問題の論点タグ・比較対象タグ（assets/questions/g_kentei.jsonl）

うかラボ「追加差別化機能」（解答後の論点別弱点・違いの比較表示）用のタグ。形式は `ukalab_core` の `Question`
（`subtopicId` / `compareWith`）に合わせる。公式シラバス・過去問の転載ではなく、自作の分類。
運営者確認前の仮分類（用語対の選び方は特に要確認）。

## 章（既存）と細目（subtopicId）

- 章 = 既存の `subjectId`（G検定の公式10項目に対応）。`subtopicId` は **`<subjectId>-<細目>`** 形式で、必ず1つの章に属する。
- 1問に細目は1つ。迷う問題は「その他」にせず、問題の主題に最も近い細目へ入れる。
- 注意: 既存データの `topicId` は問題ごとの個別トピック（章ではない）。`ukalab_core` の
  `validateAnswerFeedbackTags`（未マージ・v0.54.0 には無い）は `topicId` を章として「同じ細目が複数の章に付く」を検査するため、
  コアを更新して検査が有効になると `subtopic-conflict` になり得る。更新時は章を `subjectId` で判定する等の対応が必要。

| subtopicId | 章 | 内容・付与基準 |
|---|---|---|
| `ai_intro-definition` | ai_intro | AIの定義・強いAI/弱いAI・合理的エージェント・分類 |
| `ai_intro-symbolic_knowledge` | ai_intro | 記号処理・エキスパートシステム・知識表現・コネクショニズム |
| `ai_intro-search_reasoning` | ai_intro | 探索・推論・フレーム問題 |
| `ai_intro-philosophy_history` | ai_intro | チューリングテスト・中国語の部屋・シンギュラリティ・AIの冬など哲学論点と初期の歴史 |
| `ai_trend-history_milestones` | ai_trend | AIブーム（第1〜3次）・歴史的システム・ゲームAI等の節目 |
| `ai_trend-genai_llm` | ai_trend | 生成AI・LLM・基盤モデル・GAN/VAE・ハルシネーション |
| `ai_trend-data_compute` | ai_trend | データセット・GPU/計算資源・ベンチマーク・スケーリング則 |
| `ai_trend-deployment_trend` | ai_trend | エッジAI・連合学習・オープンソース・SLM・民主化など普及の動向 |
| `ai_trend-policy_trend` | ai_trend | 各国の戦略・サミット・規制の動向 |
| `ml_overview-learning_paradigms` | ml_overview | 教師あり/なし/強化/半教師あり等の学習の枠組み |
| `ml_overview-models_algorithms` | ml_overview | 決定木・SVM・kNN・回帰・ナイーブベイズ等の個別手法 |
| `ml_overview-ensemble` | ml_overview | アンサンブル・バギング・ブースティング・スタッキング |
| `ml_overview-unsupervised_methods` | ml_overview | クラスタリング・次元削減・異常検知・アソシエーション |
| `ml_overview-recommendation` | ml_overview | 協調フィルタリング・コンテンツベース・行列分解 |
| `ml_overview-generalization_evaluation` | ml_overview | 過学習/未学習・交差検証・正則化・評価指標・ハイパーパラメータ調整 |
| `ml_overview-data_preprocessing` | ml_overview | 特徴量設計・欠損/外れ値・エンコーディング・スケーリング・不均衡 |
| `ml_overview-interpretability` | ml_overview | モデルの解釈性・SHAP・特徴量重要度 |
| `dl_overview-network_basics` | dl_overview | パーセプトロン・MLP・順伝播/誤差逆伝播・計算グラフ・万能近似 |
| `dl_overview-optimization` | dl_overview | 勾配降下法・学習率・モーメンタム・損失関数・バッチ/エポック |
| `dl_overview-gradient_init` | dl_overview | 勾配消失/爆発・重みの初期化・勾配クリッピング |
| `dl_overview-training_practice` | dl_overview | 早期終了・重み減衰・学習曲線・ハイパーパラメータ |
| `dl_elements-layers_activation` | dl_elements | 活性化関数・ソフトマックス・交差エントロピー |
| `dl_elements-cnn_vision` | dl_elements | CNN・畳み込み/プーリング・データ拡張・ViT・距離学習 |
| `dl_elements-sequence_models` | dl_elements | RNN・LSTM・GRU・Encoder-Decoder・生成時のデコード |
| `dl_elements-transformer_attention` | dl_elements | Transformer・注意機構・位置エンコーディング・コンテキスト長 |
| `dl_elements-training_techniques` | dl_elements | 正規化層・ドロップアウト・最適化手法・混合精度・NAS |
| `dl_elements-llm_adaptation` | dl_elements | 転移学習・ファインチューニング・RLHF・LoRA・蒸留・量子化・マルチモーダル |
| `dl_elements-tokens_embedding` | dl_elements | トークナイザ・BPE・埋め込み・未知語 |
| `dl_applications-vision` | dl_applications | 画像分類・物体検出・セグメンテーション・顔認識・動画 |
| `dl_applications-nlp` | dl_applications | 翻訳・要約・QA・感情分析・チャットボット |
| `dl_applications-speech_audio` | dl_applications | 音声認識・音声合成・話者認識・音楽生成 |
| `dl_applications-generative_models` | dl_applications | GAN・拡散モデル・テキストから画像・生成モデルの役割 |
| `dl_applications-rag_llm` | dl_applications | RAG（検索拡張生成）・事前学習とファインチューニング |
| `dl_applications-prediction_analytics` | dl_applications | 需要/時系列予測・異常/不正検知・推薦・最適化 |
| `dl_applications-domain_applications` | dl_applications | 医療・農業・製造・自動運転・教育など分野別の活用 |
| `ai_social-project_process` | ai_social | PoC・MLOps・プロジェクトの進め方・失敗要因・運用 |
| `ai_social-data_management` | ai_social | データ品質・ラベリング・バイアス・個人データの扱い |
| `ai_social-organization_governance` | ai_social | 人材・体制・戦略・ガバナンス・調達・導入の課題 |
| `math_stats-probability_bayes` | math_stats | 確率・条件付き確率・ベイズ・尤度・独立性 |
| `math_stats-distributions_descriptive` | math_stats | 確率分布・期待値/分散・大数の法則/中心極限定理・記述統計 |
| `math_stats-statistical_inference` | math_stats | 仮説検定・p値・信頼区間・相関・標本 |
| `math_stats-linear_algebra_calculus` | math_stats | ベクトル・行列・固有値・微分・凸最適化・ノルム |
| `math_stats-metrics_information` | math_stats | 混同行列・適合率/再現率・ROC・エントロピー |
| `ai_law-copyright_ai` | ai_law | 著作権（30条の4・AI生成物・類似性/依拠・学習データ） |
| `ai_law-ip_licenses` | ai_law | 特許・営業秘密・商標・ライセンス・オープンデータ |
| `ai_law-personal_data` | ai_law | 個人情報保護・匿名加工・GDPR・越境移転・生体情報 |
| `ai_law-contract_liability` | ai_law | 開発/利用契約・製造物責任・利用規約・消費者保護 |
| `ai_law-eu_international_rules` | ai_law | EU AI Act・国際標準・越境サービス・輸出管理・認証 |
| `ai_law-domestic_sector_rules` | ai_law | 国内の分野別規制・ガイドライン・独禁法・説明義務・監査 |
| `ai_ethics-guidelines` | ai_ethics | 国のAI事業者ガイドライン・OECD原則・人間中心の原則 |
| `ai_ethics-fairness_bias` | ai_ethics | 公平性・バイアス・デジタルデバイド・文化差 |
| `ai_ethics-transparency_explainability` | ai_ethics | 説明可能性・透明性・説明責任・監査・影響評価 |
| `ai_ethics-safety_risk` | ai_ethics | 安全性・ハルシネーション・ディープフェイク・レッドチーム・リスク |
| `ai_ethics-privacy_society` | ai_ethics | プライバシー・同意・雇用・依存・環境など社会への影響 |
| `ai_ethics-governance_org` | ai_ethics | 倫理委員会・責任あるAI・ステークホルダー・ガバナンス体制 |

## 比較対象（compareWith）の付け方

- 値は **用語データ `assets/terms/g_kentei.jsonl` の `termId` の配列**（`ukalab_core` の `Question.compareWith` と `validateCompareTargets` の定義）。
  問題IDではない。
- 「答えの用語」は、用語側 `relatedQuestionIds` にその問題の `qid` を持つ用語。`compareWith` には答えの用語自身を入れない（`compare-self`）。
- 付ける問題: 答えの用語と、紛らわしい別の用語（過学習と未学習、適合率と再現率、LSTMとGRU 等）を並べて違いを見せる意味がある問題だけ。
  今回は ai_trend / ml_overview / dl_overview / dl_elements / math_stats のうち、紛らわしい用語対がある問題に限る。
  `tools/question_tags/assign_tags.py` の `COMPARE_GROUPS`（用語の組）から機械的に付与し、1問あたり最大3つ。
- 同じ概念を指す重複用語（適合率・再現率が ml_overview と math_stats に2つある等）は互いを比較対象にしない。
- 答えの用語が無い問題（用語データ未対応）、比較する相手がいない問題には付けない。無理に全問へ付けない。

## 検証

`python3 tools/question_tags/validate_question_tags.py`（JSON妥当性・qid重複なし・細目の語彙がこの表と一致・
細目が章のプレフィックスと一致・`compareWith` の参照先が実在かつ自己参照でない・
`answerIndex`/選択肢など既存項目が元の `origin/main` から不変）。

## 観点（conceptId / angle）と AI 下書きタグ（multi-angle パイロット）

ukalab_core v0.75.0 の `Question.conceptId` / `angle` / `tags` を使う。設計は ukalab_core `docs/multi_angle_questions_design.md`。

- `conceptId`: 用語データの `termId` と同じ値（例: `g_kentei_term-0013`）。
- `angle`: `definition`（定義・性質）/ `scenario`（事例に当てはめる）/ `comparison`（紛らわしい相手との違い。必要なら `compareWith` を併用）/ `reverse`（説明から用語を当てる）。新しい問題タイプ（trueFalse / cloze / reverseLookup）は、アプリに UI が入るまで追加しない。
- `tags: ["ai-draft"]`: **AI が下書きし、人（運営者・専門家）の事実確認が済んでいない問題**。新規に AI が書いた問題には必ず付ける。確認が済んだら人が外す。`ai-draft` が残る問題は、広告表現（「別の角度で」等）の根拠に数えない。
- 用語側 `relatedQuestionIds` には、その概念の問題（逆引き以外の観点も）を追加する。
- パイロットの結果は `docs/angle_coverage_pilot.md`。
