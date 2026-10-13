#!/usr/bin/env python3
"""論点タグ・比較対象タグの検証。失敗時は終了コード1。
使い方: python3 tools/question_tags/validate_question_tags.py [--base origin/main]
--base を省略すると、git で origin/main があれば既存項目の不変チェックも行う。"""
import json, re, subprocess, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
QPATH = 'assets/questions/g_kentei.jsonl'
errors = []


def err(m): errors.append(m)


def parse(text, label):
    rows = []
    for i, l in enumerate(text.split('\n'), 1):
        if not l.strip() or l.startswith('//'):
            continue
        try:
            rows.append(json.loads(l))
        except Exception as e:
            err(f'{label}:{i} JSONが不正: {e}')
    return rows


qs = parse((ROOT / QPATH).read_text(encoding='utf-8'), QPATH)
terms = {t['termId']: t for t in parse((ROOT / 'assets/terms/g_kentei.jsonl').read_text(encoding='utf-8'), 'terms')}

vocab = set(re.findall(r'^\| `([a-z_]+-[a-z_]+)` \|', (ROOT / 'docs/question_tags.md').read_text(encoding='utf-8'), re.M))
if not vocab:
    err('docs/question_tags.md から語彙を読めません')

seen = set()
used = set()
answer_terms = {}
for t in terms.values():
    for qid in t.get('relatedQuestionIds', []):
        answer_terms.setdefault(qid, set()).add(t['termId'])
n_sub = n_cmp = 0
for q in qs:
    qid = q['qid']
    if qid in seen: err(f'{qid}: qid重複')
    seen.add(qid)
    sub = q.get('subtopicId')
    if sub is None:
        err(f'{qid}: subtopicId なし')
    else:
        n_sub += 1
        used.add(sub)
        if sub not in vocab: err(f'{qid}: subtopicId "{sub}" が question_tags.md に無い')
        if not sub.startswith(q['subjectId'] + '-'): err(f'{qid}: subtopicId "{sub}" が章 {q["subjectId"]} と一致しない')
    cw = q.get('compareWith')
    if cw is not None:
        n_cmp += 1
        if not isinstance(cw, list) or not cw: err(f'{qid}: compareWith が空/配列でない')
        else:
            if len(set(cw)) != len(cw): err(f'{qid}: compareWith 重複')
            for c in cw:
                if c not in terms: err(f'{qid}: compareWith "{c}" が用語データに無い')
                elif c in answer_terms.get(qid, ()): err(f'{qid}: compareWith "{c}" は答えの用語自身')
            if not answer_terms.get(qid) and len(cw) < 2: err(f'{qid}: 答えの用語が無く比較表示が作れない')
for v in sorted(vocab - used): err(f'語彙 "{v}" を使う問題が無い')

base = sys.argv[sys.argv.index('--base') + 1] if '--base' in sys.argv else 'origin/main'
try:
    old_text = subprocess.run(['git', 'show', f'{base}:{QPATH}'], cwd=ROOT, capture_output=True, text=True, check=True).stdout
except Exception:
    old_text = None
    print('(base が無いので既存項目の不変チェックはスキップ)')
if old_text is not None:
    old = {q['qid']: q for q in parse(old_text, 'base')}
    if set(old) != {q['qid'] for q in qs}: err('問題の集合（qid）がbaseと違う')
    for q in qs:
        o = old.get(q['qid'])
        if o is None: continue
        cur = {k: v for k, v in q.items() if k not in ('subtopicId', 'compareWith')}
        if cur != o: err(f'{q["qid"]}: 既存項目が変更されている')

print(f'questions={len(qs)} subtopicId={n_sub} compareWith={n_cmp} vocab={len(vocab)} used={len(used)}')
if errors:
    print('\n'.join(errors[:50])); print(f'NG: {len(errors)}件'); sys.exit(1)
print('OK')
