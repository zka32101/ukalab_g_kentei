// アプリ（Flutter Web）を Playwright で操作して、主要タブ・設定の購入欄・受験日を確認する。
//   node check.js [スクリーンショットの保存先]
// 期待値は環境変数で渡す（アプリごとに違うため）:
//   E2E_SETTINGS   設定タブに出るはずの文言（カンマ区切り）
//   E2E_EXAM_DATE  1 なら、受験日の入力→再読み込みで残る→解除 を確認する
//   E2E_HOME / E2E_LEARN / E2E_MOCK  ホーム／学ぶ／模擬に出るはずの文言（カンマ区切り）
// Flutter Web は文字をキャンバスに描くので、アクセシビリティ（semantics）を有効にして文字とボタンを拾う。
const { chromium } = require('playwright');

const shots = process.argv[2] || '.';
const settingsExpect = (process.env.E2E_SETTINGS || '購入,ながら学習モード').split(',').filter(Boolean);
const examDate = process.env.E2E_EXAM_DATE === '1';
const tabs = ['ホーム', '学ぶ', '模擬', '記録', '設定'];
const failures = [];

function check(name, ok) {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${name}`);
  if (!ok) failures.push(name);
}

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined, args: ['--no-sandbox'] });
  const page = await browser.newPage({ locale: 'ja-JP', viewport: { width: 420, height: 1000 } });
  const errors = [];
  page.on('pageerror', e => errors.push(e.stack || e.message || String(e)));
  // 起動しないときの原因を追えるよう、ブラウザのコンソールのエラーも出す。
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') console.log(`[console.${m.type()}] ${m.text().slice(0, 400)}`); });
  page.on('requestfailed', r => console.log(`[requestfailed] ${r.url()} ${r.failure()?.errorText}`));

  // 文字は innerText と aria-label の両方から拾う（タブやボタンの名前は aria-label にだけ入る）。
  const text = async () =>
    page.evaluate(() =>
      [...document.querySelectorAll('flt-semantics')]
        .map(e => `${e.innerText || ''}\n${e.getAttribute('aria-label') || ''}`)
        .join('\n'));
  const waitText = async (s, timeout = 8000) => {
    const end = Date.now() + timeout;
    while (Date.now() < end) {
      if ((await text()).includes(s)) return true;
      await page.waitForTimeout(200);
    }
    return false;
  };
  const click = async (name) => {
    const byRole = page.getByRole('tab', { name, exact: false });
    const loc = (await byRole.count()) > 0 ? byRole : page.getByRole('button', { name, exact: false });
    await loc.first().click({ force: true, timeout: 5000 });
    await page.waitForTimeout(700);
  };
  const boot = async () => {
    await page.goto('http://localhost:8099/');
    await page.waitForSelector('flt-semantics-placeholder', { state: 'attached', timeout: 90000 });
    await page.evaluate(() => document.querySelector('flt-semantics-placeholder').click());
    await page.waitForTimeout(1500);
  };

  await boot();
  const booted = await waitText('ホーム', 20000);
  check('起動してホームが出る', booted);
  if (!booted) {
    console.log(`--- 起動後の画面の文字 ---\n${(await text()).slice(0, 800)}\n--- ページエラー ---\n${errors.join('\n')}`);
    await page.screenshot({ path: `${shots}/boot-failed.png` });
    await browser.close();
    process.exit(1);
  }
  await page.screenshot({ path: `${shots}/home.png` });

  // 5つのタブを順に開く
  for (const t of tabs) {
    check(`タブ「${t}」がある`, await waitText(t));
  }
  for (const t of tabs.slice(1, 4)) {
    await click(t);
    await page.screenshot({ path: `${shots}/tab-${t}.png` });
  }
  check('ページエラーなし（各タブ）', errors.length === 0);

  // アプリ固有の文言（ホーム／学ぶ／模擬）。E2E_HOME / E2E_LEARN / E2E_MOCK にカンマ区切りで渡す。
  const expectOn = async (tab, env) => {
    const items = (process.env[env] || '').split(',').filter(Boolean);
    if (!items.length) return;
    await click(tab);
    for (const s of items) check(`${tab}に「${s}」`, await waitText(s));
  };
  await expectOn('ホーム', 'E2E_HOME');
  await expectOn('学ぶ', 'E2E_LEARN');
  await expectOn('模擬', 'E2E_MOCK');

  // 設定タブ
  await click('設定');
  for (const s of settingsExpect) check(`設定に「${s}」`, await waitText(s));
  await page.screenshot({ path: `${shots}/settings.png` });

  if (examDate) {
    const today = await page.evaluate(() => {
      const d = new Date();
      return `${d.getFullYear()}/${d.getMonth() + 1}/${d.getDate()}`;
    });
    check('受験日は未設定', await waitText('未設定'));
    await click('受験日');
    await click('OK');
    check(`受験日に今日（${today}）が入る`, await waitText(today));
    await page.screenshot({ path: `${shots}/exam-date-set.png` });

    // 再読み込みしても残る（端末内の保存）
    await boot();
    await click('設定');
    check('再読み込み後も受験日が残る', await waitText(today));

    await click('受験日を解除');
    check('受験日を解除すると未設定に戻る', await waitText('未設定'));
  }

  check('ページエラーなし', errors.length === 0);
  if (errors.length) console.log(errors.join('\n'));
  await browser.close();
  if (failures.length) {
    console.log(`\n${failures.length} 件失敗`);
    process.exitCode = 1;
  }
})();
