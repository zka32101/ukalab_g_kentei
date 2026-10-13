#!/usr/bin/env python3
"""g_kentei.jsonl に subtopicId / compareWith を付与する（元データに対して1回実行する）。

- 元の行の文字列は一切書き換えず、末尾に項目を追記するだけ（answerIndex・選択肢は不変）
- subtopicId: 章(subjectId)ごとの語彙 + topicId の規則（下の RULES / OVERRIDES）で分類
- compareWith: 用語データ(assets/terms)の termId。紛らわしい用語の組(COMPARE_GROUPS)から、
  答えの用語（relatedQuestionIds にその qid を持つ用語）以外のメンバーを入れる
語彙と付与基準は docs/question_tags.md が正本。
"""
import json, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
QFILE = ROOT / 'assets/questions/g_kentei.jsonl'
TFILE = ROOT / 'assets/terms/g_kentei.jsonl'

# 先に OVERRIDES(topicId 完全一致) → 次に RULES(正規表現, 上から最初に当たったもの)
OVERRIDES = {
 # ai_trend
 'breadth_first_search_vs_dfs': 'history_milestones', 'alphago': 'history_milestones',
 'game_ai_milestones_statement': 'history_milestones', 'alphafold': 'history_milestones',
 'self_driving_progress': 'history_milestones', 'gan_goodfellow': 'genai_llm',
 'ai_regulation_global_divergence': 'policy_trend',
 'edge_ai_trend': 'deployment_trend', 'federated_learning': 'deployment_trend',
 'ai_democratization': 'deployment_trend', 'no_code_ai_tool': 'deployment_trend',
 'small_language_model_trend': 'deployment_trend', 'open_source_llm': 'deployment_trend',
 'synthetic_data_usage': 'deployment_trend',
 # ml_overview
 'hyperparameter_tuning': 'generalization_evaluation', 'grid_search': 'generalization_evaluation',
 'model_interpretability': 'interpretability', 'shap_values': 'interpretability',
 'feature_importance': 'interpretability', 'permutation_importance': 'interpretability',
 'isolation_forest': 'unsupervised_methods', 'one_class_svm': 'unsupervised_methods',
 'gaussian_mixture_model': 'unsupervised_methods',
 'collaborative_filtering': 'recommendation', 'content_based_filtering': 'recommendation',
 'matrix_factorization': 'recommendation',
 # dl_overview
 'autoencoder': 'network_basics',
 'vanishing_gradient': 'gradient_init', 'exploding_gradient': 'gradient_init',
 'vanishing_exploding_mitigation': 'gradient_init', 'sigmoid_vanishing_cause': 'gradient_init',
 'zero_initialization_problem': 'gradient_init', 'xavier_initialization': 'gradient_init',
 'he_initialization': 'gradient_init', 'gradient_clipping': 'gradient_init',
 'dead_neuron_problem': 'gradient_init', 'blank_backprop_vanishing': 'gradient_init',
 # dl_elements
 'weight_initialization': 'training_techniques', 'embedding_dimension': 'tokens_embedding',
 'capsule_network': 'cnn_vision', 'gn3_token_neg': 'tokens_embedding',
 'temperature_top_k_sampling': 'sequence_models',
 'mixture_of_experts': 'llm_adaptation', 'sparse_vs_dense_model': 'llm_adaptation',
 # dl_applications
 'text_to_image': 'generative_models',
 # ai_social
 'model_monitoring': 'project_process', 'ai_generated_content_ip_rights': 'data_management',
 # math_stats
 'confusion_matrix': 'metrics_information', 'l1_l2_difference': 'linear_algebra_calculus',
 'covariance': 'statistical_inference', 'combinatorics_basic': 'probability_bayes',
 'median_mode': 'distributions_descriptive', 'outlier_statistics': 'distributions_descriptive',
 'descriptive_statistics_statement': 'distributions_descriptive',
 # ai_ethics
 'copyright_training_data': 'privacy_society',
}

RULES = {
'ai_intro': [
 ('definition', r'ai_definition|strong_weak|weak_ai|rational_agent|agent_env|four_cat|percept|field_breadth|bounded'),
 ('symbolic_knowledge', r'expert|symbolic|semantic_network|production|connectionism|logic_theorist|general_problem|common_sense|cybernetics|mycin|dendral'),
 ('search_reasoning', r'heuristic|frame_problem'),
 ('philosophy_history', r'turing|chinese|singularity|moravec|symbol_grounding|winter|strong_ai_feas'),
],
'ai_trend': [
 ('history_milestones', r'boom|first_|second_|cyc|perceptrons|backpropagation_redisc|svm_pop|eliza|shrdlu|deep_blue|watson|turing_award|winter'),
 ('data_compute', r'imagenet|big_data|gpu|chip|compute|data_center|resnet|mnist|coco|benchmark|scaling|talent|quantum'),
 ('genai_llm', r'gen|llm|gpt|bert|stable|diffusion|multimodal|prompt|agent|rag|halluc|text_to|video|vae|seq2seq|word2vec|attention|conversational|foundation|world_model|rlhf|multi_agent|agi|watermark|transformer|embodied'),
 ('policy_trend', r'summit|hiroshima|regulation|strategy|eu_ai'),
],
'ml_overview': [
 ('learning_paradigms', r'supervised|reinforcement|semi_|online_learning|active_learning|learning_paradigms|self_training|transfer|cold_start|concept_drift|automl|blank_unsup'),
 ('models_algorithms', r'decision_tree|svm|knn|random_forest|naive|linear_reg|logistic|polynomial|gini|information_gain|kernel|margin|decision_boundary|ridge|lasso|elastic|markov'),
 ('ensemble', r'ensemble|bagging|boosting|stacking|out_of_bag'),
 ('unsupervised_methods', r'cluster|dimension|pca|kmeans|elbow|silhouette|association|t_sne|curse'),
 ('generalization_evaluation', r'overfit|underfit|cross_valid|k_fold|leave|stratified|bias_variance|train_test|data_leakage|pipeline_data|precision|f1|evaluation|model_eval|model_selection|baseline|time_series_split|learning_curve|regulariz|blank_underfit'),
 ('data_preprocessing', r'feature|missing|one_hot|normaliz|imbalanced|outlier|label_noise|scaling'),
],
'dl_overview': [
 ('network_basics', r'perceptron|multilayer|deep_learning_def|universal|forward|computational_graph|autodiff|deep_vs|model_capacity|end_to_end|activation|skip|layer_norm|chain_rule|backprop'),
 ('optimization', r'gradient|learning_rate|momentum|stochastic|batch|epoch|loss|warmup|local_minima'),
 ('training_practice', r'early_stopping|weight_decay|regulariz|learning_curve|hyperparameter|validation'),
],
'dl_elements': [
 ('layers_activation', r'activation|relu|sigmoid|softmax|gelu|cross_entropy'),
 ('cnn_vision', r'cnn|pooling|convolution|vision_transformer|siamese|triplet|data_aug'),
 ('sequence_models', r'rnn|lstm|gru|bidirectional|teacher_forcing|beam|encoder_decoder'),
 ('transformer_attention', r'attention|transformer|positional|multi_head|causal|gpt_|bert_|padding|long_context|context_length'),
 ('training_techniques', r'normalization|dropout|gradient_acc|mixed_prec|checkpoint|bayesian|neural_arch|residual|optimizer'),
 ('llm_adaptation', r'fine_tuning|transfer|few_shot|zero_shot|in_context|instruction|rlhf|lora|parameter_eff|distill|quantiz|pruning|catastrophic|prompt_inj|gn3|contrastive|clip|multimodal'),
 ('tokens_embedding', r'token|word_embedding|embedding|byte_pair|out_of_vocab'),
],
'dl_applications': [
 ('rag_llm', r'gn3_rag|gn3_pretrain'),
 ('generative_models', r'gan_basics|diffusion|generative|watermark|virtual_influencer'),
 ('speech_audio', r'speech|speaker|noise|music|text_to_speech|tts'),
 ('vision', r'image|object_det|segment|face|pose|super_res|style|video|medical_image|scene|3d|gesture|facial|visual|deepfake|inpaint|document_ai|cv_task|lip_sync|virtual_try'),
 ('nlp', r'translation|sentiment|summar|question_answering|named_entity|chatbot|code_gen|nlp_task|plagiar|moderation|customer_(service|voice)|journalism|language_learning|contract_review|bleu|tutoring_chatbot'),
 ('prediction_analytics', r'forecast|predict|optimi|anomaly|fraud|churn|pricing|recommend|demand|valuation|yield|energy|insurance|supply|scoring'),
 ('domain_applications', r'.*'),
],
'ai_social': [
 ('project_process', r'poc|pilot|project|mlops|ab_testing|roi|success_metric|decommission|stakeholder|documentation|redundancy|pipeline|procurement_req|operation'),
 ('data_management', r'data|label|bias|privacy|personal'),
 ('organization_governance', r'.*'),
],
'math_stats': [
 ('probability_bayes', r'bayes|probab|prior|likelihood|maximum_likelihood|independ|joint|total_prob|markov|blank_bayes'),
 ('distributions_descriptive', r'distribution|normal|poisson|binomial|central_limit|large_numbers|skew|kurt|expected|variance|standard_dev|z_score'),
 ('statistical_inference', r'hypothesis|p_value|confidence|chi_square|t_test|anova|significance|sampl|correlation|multicollin|pvalue'),
 ('linear_algebra_calculus', r'vector|eigen|matrix|derivative|chain_rule|convex|norm'),
 ('metrics_information', r'entropy|cross_entropy|confusion|precision|f1|roc|metrics|classification'),
],
'ai_law': [
 ('copyright_ai', r'copyright|ai_generated_work|training_data|infringement'),
 ('ip_licenses', r'patent|trademark|trade_secret|license|open_data'),
 ('personal_data', r'personal|privacy|sensitive|anonym|pseudonym|biometric|children|forgotten|portab|retention|ppc|limited_provided|purpose|data_use|cross_border_data|gdpr|cross_industry'),
 ('contract_liability', r'contract|warranty|liability|terms|subcontract|dev_contract|insurance|defamation|impersonation|consumer|unfair|advertising|service_terms|standard_contract'),
 ('eu_international_rules', r'ai_act|international|cross_border|export|jurisdiction|certification|standard'),
 ('domestic_sector_rules', r'.*'),
],
'ai_ethics': [
 ('guidelines', r'gn3_guideline|inappropriate_(human_centric|ai_guideline|oecd|ai_governance)'),
 ('fairness_bias', r'bias|fair|discrimin|cultural|divide|south|vulnerable'),
 ('transparency_explainability', r'xai|explain|transparen|model_cards|accountab|disclosure|trust|audit|impact_assess'),
 ('safety_risk', r'safety|red_team|dual_use|existential|weapon|halluc|deepfake|synthetic|precaution|incident|dark_pattern|surveil|facial|genai_risk|alignment|risk'),
 ('privacy_society', r'privacy|consent|autonomy|wellbeing|employment|filter|creativity|anthropomorph|personification|dependency|environment|for_good|literacy|copyright'),
 ('governance_org', r'.*'),
],
}

# 紛らわしい用語の組（termId の数字部分）。メンバー同士を比較対象にする。
# TWINS は同じ概念の重複用語（互いを比較対象にしない）。
COMPARE_GROUPS = [
 [13, 144, 142, 119],            # 過学習 / 未学習 / バイアス・バリアンス / 正則化
 [11, 12, 15, 135],              # 教師あり / なし / 強化 / 半教師あり
 [116, 117, 109, 118, 108],      # アンサンブル / バギング / ブースティング / スタッキング / RF
 [130, 131, 37, 304],            # 適合率・再現率 / ROC-AUC / 混同行列 / F1
 [303, 305, 37, 304],
 [119, 164, 158, 197],           # 過学習対策: 正則化 / 重み減衰 / 早期終了 / データ拡張
 [21, 182, 184, 183],            # 活性化関数
 [195, 176, 145],                # バッチ正規化 / レイヤー正規化 / スケーリング
 [22, 23, 24],                   # CNN / RNN / Transformer
 [23, 185, 186, 187],            # RNN / LSTM / GRU / 双方向RNN
 [189, 190, 191, 25],            # 自己注意 / 交差注意 / マルチヘッド / Attention
 [198, 200, 199],                # 転移学習 / ファインチューニング / 事前学習
 [213, 214, 215],                # ゼロショット / フューショット / インコンテキスト
 [210, 211, 212],                # 蒸留 / 量子化 / 枝刈り
 [162, 171, 165, 166],           # 勾配消失 / クリッピング / Xavier / He
 [18, 163, 157, 169],            # 勾配降下 / モーメンタム / 学習率 / スケジューリング
 [17, 159, 160, 173],            # 誤差逆伝播 / 順伝播 / 計算グラフ / 自動微分
 [6, 66, 67],                    # 第3次 / 第1次 / 第2次AIブーム
 [68, 69, 70],                   # AlphaGo / ディープ・ブルー / Watson
 [99, 100, 76],                  # GAN / VAE / Stable Diffusion
 [88, 75, 8, 105],               # BERT / GPT / LLM / 基盤モデル
 [8, 106, 79],                   # LLM / SLM / オープンソースLLM
 [78, 200, 72],                  # RAG / ファインチューニング / プロンプト
 [94, 95],                       # ELIZA / SHRDLU
 [81, 104],                      # エッジAI / 連合学習
 [107, 108, 110, 111],           # 決定木 / RF / SVM / kNN
 [114, 115, 113, 112],           # クラスタリング / k-means / PCA / 次元削減
 [139, 140, 141],                # 線形回帰 / ロジスティック / ナイーブベイズ
 [133, 134],                     # ジニ不純度 / 情報利得
 [147, 148, 146, 125],           # k分割 / 層化 / 分割 / データリーク
 [151, 152],                     # 協調フィルタリング / 行列分解
 [153, 127, 126],                # 特徴量重要度 / SHAP / 解釈性
 [149, 150, 115],                # エルボー / シルエット / k-means
 [307, 308],                     # 中心極限定理 / 大数の法則
 [311, 39, 310],                 # 分散 / 標準偏差 / 期待値
 [306, 330],                     # 相関係数 / 共分散
 [316, 315, 38],                 # 二項 / ポアソン / 正規
 [328, 329, 327, 326, 36, 309],  # 尤度 / 最尤 / 事前事後 / ベイズ推論 / ベイズの定理 / 条件付確率
 [324, 323, 325, 312, 40, 321],  # t検定 / カイ二乗 / ANOVA / 仮説検定 / p値 / 信頼区間
 [317, 318, 322],                # 中央値 / 外れ値 / Zスコア
]
TWINS = [(130, 303), (131, 305)]
MAX_COMPARE = 3
COMPARE_CHAPTERS = {'ai_trend', 'ml_overview', 'dl_overview', 'dl_elements', 'math_stats'}


def tid(n): return f'g_kentei_term-{n:04d}'


def classify(q):
    ch, t = q['subjectId'], q['topicId']
    sub = OVERRIDES.get(t)
    if sub is None:
        for s, rx in RULES[ch]:
            if re.search(rx, t):
                sub = s
                break
    return f'{ch}-{sub}'


def load(path):
    return [l for l in path.read_text(encoding='utf-8').split('\n')]


def main():
    terms = {}
    for l in load(TFILE):
        if l.strip() and not l.startswith('//'):
            t = json.loads(l)
            terms[t['termId']] = t
    answer_term = {}
    for t in terms.values():
        for qid in t.get('relatedQuestionIds', []):
            answer_term.setdefault(qid, []).append(t['termId'])
    twin = {frozenset((tid(a), tid(b))) for a, b in TWINS if a != b}

    out, n_sub, n_cmp = [], 0, 0
    for l in load(QFILE):
        if not l.strip() or l.startswith('//'):
            out.append(l)
            continue
        q = json.loads(l)
        if 'subtopicId' in q or 'compareWith' in q:
            sys.exit('既にタグが付いています。git checkout で元のデータに戻してから実行してください')
        extra = {'subtopicId': classify(q)}
        n_sub += 1
        if q['subjectId'] in COMPARE_CHAPTERS and q['qid'] in answer_term:
            ans = answer_term[q['qid']]
            cands = []
            for g in COMPARE_GROUPS:
                ids = [tid(n) for n in g]
                if any(a in ids for a in ans):
                    for i in ids:
                        if i in terms and i not in ans and i not in cands \
                           and not any(frozenset((a, i)) in twin for a in ans):
                            cands.append(i)
            cands = cands[:MAX_COMPARE]
            if cands:
                extra['compareWith'] = cands
                n_cmp += 1
        base = l.rstrip()
        # 元の文字列は触らず、末尾に追記する（既存項目は不変）
        add = ''.join(',' + json.dumps(k, ensure_ascii=False) + ':' + json.dumps(v, ensure_ascii=False, separators=(',', ':')) for k, v in extra.items())
        out.append(base[:-1] + add + '}')
    QFILE.write_text('\n'.join(out), encoding='utf-8')
    print('subtopicId', n_sub, 'compareWith', n_cmp)


if __name__ == '__main__':
    main()
