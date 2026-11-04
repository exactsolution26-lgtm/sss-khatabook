// Run against the built web application served on port 8080, never production.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
(async () => {
  const browser = await chromium.launch({headless: true});
  const page = await browser.newPage({viewport: {width: 1280, height: 900}, locale: 'en-IN', timezoneId: 'Asia/Kolkata'});
  const errors = [];
  const diagnostic = [];
  const text = name => page.getByText(name, {exact: true})
    .or(page.getByLabel(name, {exact: true})).first();
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    diagnostic.push(message.type() + ': ' + message.text());
    if (/SSS_(FRAMEWORK_ERROR|ASYNC_ERROR|STARTUP_INITIALIZATION_FAILED)/.test(message.text())) errors.push(message.text());
  });
  try {
  await page.goto('http://127.0.0.1:8080', {waitUntil: 'networkidle'});
  // Flutter engine DOM wrappers vary by version; await the accessibility entry point.
  await page.locator('flt-semantics-placeholder').waitFor({state: 'attached', timeout: 60000});
  const semantics = page.locator('flt-semantics-placeholder');
  if (await semantics.count()) await semantics.evaluate(el => el.click());
  await text('Your business, clearly accounted for.').waitFor({timeout: 60000});
  await text('Accounts').click();
  await text('New Account').click();
  await page.getByRole('textbox', {name: 'Account name'}).fill('Browser acceptance account');
  await page.getByRole('textbox', {name: 'Opening balance (₹)'}).fill('100.00');
  await page.getByRole('button', {name: 'Save', exact: true}).click();
  await text('Browser acceptance account').waitFor();
  await page.reload({waitUntil: 'networkidle'});
  await page.locator('flt-semantics-placeholder').waitFor({state: 'attached', timeout: 60000});
  const again = page.locator('flt-semantics-placeholder');
  if (await again.count()) await again.evaluate(el => el.click());
  await text('Accounts').click();
  await text('Browser acceptance account').waitFor();
  await page.screenshot({path: 'web-desktop.png'});
  await page.setViewportSize({width: 390, height: 844});
  await page.screenshot({path: 'web-mobile.png'});
  assert.deepEqual(errors, [], 'Browser runtime must have no unhandled page errors');
  console.log('PASS: startup, real IndexedDB account create/persistence, desktop/mobile rendering');
  } finally {
    await page.screenshot({path: 'web-final-state.png'});
    fs.writeFileSync('web-runtime.log', diagnostic.concat(errors).join('\n'));
    fs.writeFileSync('web-dom.html', await page.content());
    await browser.close();
  }
})().catch(error => { console.error(error); process.exit(1); });
