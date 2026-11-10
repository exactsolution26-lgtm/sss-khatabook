// Run against the built web application served on port 8080, never production.
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
(async () => {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'sss-browser-'));
  const options = {headless: true, viewport: {width: 1280, height: 900}, locale: 'en-IN', timezoneId: 'Asia/Kolkata'};
  let context = await chromium.launchPersistentContext(profile, options);
  let page = await context.newPage();
  const errors = [];
  const diagnostic = [];
  const text = name => page.getByText(name, {exact: true})
    .or(page.getByLabel(name, {exact: true})).first();
  const observe = () => {
  page.on('pageerror', error => errors.push(String(error)));
  page.on('console', message => {
    diagnostic.push(message.type() + ': ' + message.text());
    if (/SSS_(FRAMEWORK_ERROR|ASYNC_ERROR|STARTUP_INITIALIZATION_FAILED)/.test(message.text())) errors.push(message.text());
  });
  };
  observe();
  const enableSemantics = async () => {
    await page.locator('flt-semantics-placeholder, flt-semantics-host flt-semantics').first().waitFor({state:'attached', timeout:60000});
    const placeholder = page.locator('flt-semantics-placeholder');
    if (await placeholder.count()) await placeholder.evaluate(el => el.click());
  };
  const openProfile = async () => {
    await page.getByRole('button', {name:'Settings',exact:true}).first().click();
    await page.mouse.move(640,600); await page.mouse.wheel(0,500);
    await text('Business Profile').click();
    await page.getByRole('textbox', {name:'Business name',exact:true}).waitFor();
  };
  const focusProfileInput = async label => {
    const field = page.getByRole('textbox', {name:label, exact:true});
    await field.click();
    await checkProfileInput(label);
    return field;
  };
  const fillProfileInput = async (label, value) => {
    const field = await focusProfileInput(label);
    // Enter text through the browser editor after Flutter has handled focus.
    await field.press('Home');
    await field.fill(value);
    await checkProfileInput(label, value);
  };
  const checkProfileInput = async (label, expected = null) => {
    await page.waitForFunction(({label, expected}) => {
      let field = document.activeElement;
      while (field?.shadowRoot?.activeElement) field = field.shadowRoot.activeElement;
      const activeLabel = field?.getAttribute('aria-label');
      return field instanceof HTMLInputElement && (!activeLabel || activeLabel === label) &&
        (expected === null || field.value === expected);
    }, {label, expected});
  };
  const returnHomeFromProfile = async () => {
    await page.getByRole('button', {name:'Back',exact:true}).click();
    await page.getByRole('button', {name:'Back',exact:true}).click();
    await text('Active: Timeline').waitFor();
  };
  try {
  await page.goto('http://127.0.0.1:8080', {waitUntil: 'domcontentloaded', timeout: 60000});
  // Flutter engine DOM wrappers vary by version; await the accessibility entry point.
  await page.locator('flt-semantics-placeholder').waitFor({state: 'attached', timeout: 60000});
  const semantics = page.locator('flt-semantics-placeholder');
  if (await semantics.count()) await semantics.evaluate(el => el.click());
  await text('Your business, clearly accounted for.').waitFor({timeout: 60000});
  await text('Accounts').click();
  await text('New Account').click();
  const nameField = page.getByRole('textbox', {name: 'Account name'});
  await nameField.click();
  await nameField.pressSequentially('Browser acceptance account');
  const opening = page.getByRole('textbox', {name: 'Opening balance (₹)'});
  await opening.click();
  // Flutter's semantics proxy does not reliably forward select-all shortcuts.
  // Use normal editing keys and assert the final persisted amount below.
  await opening.press('End');
  for (let i = 0; i < 12; i++) await opening.press('Backspace');
  await opening.pressSequentially('100.00', {delay: 25});
  await opening.press('Tab');
  diagnostic.push('Entered opening balance: ' + await opening.inputValue());
  await page.getByRole('button', {name: 'Save', exact: true}).click();
  const record = () => page.getByRole('button', {name: /^Browser acceptance account\s+Opening:/});
  await record().waitFor();
  assert.match(await record().getAttribute('aria-label'), /Opening: ₹100\.00/);
  await page.reload({waitUntil: 'domcontentloaded', timeout: 60000});
  await page.locator('flt-semantics-placeholder').waitFor({state: 'attached', timeout: 60000});
  const again = page.locator('flt-semantics-placeholder');
  if (await again.count()) await again.evaluate(el => el.click());
  // Reload retains the /accounts route. Verify its record, then use the real Back control.
  await record().waitFor();
  assert.match(await record().getAttribute('aria-label'), /Opening: ₹100\.00/);
  await page.getByRole('button', {name:'Back', exact:true}).click();
  await text('Active: Classic').waitFor();
  await text('Change dashboard').click();
  await page.getByRole('button', {name:/\bClassic\b/}).click();
  await text('Timeline').click();
  await text('Use this dashboard').click();
  await text('Active: Timeline').waitFor();
  // Preview another design, then cancel. The actual selected design must survive.
  await text('Change dashboard').click();
  await page.getByRole('button', {name:/\bTimeline\b/}).click();
  await text('Compact').click();
  await page.getByRole('button', {name:'Back', exact:true}).click();
  await text('Active: Timeline').waitFor();
  await page.screenshot({path:'web-dashboard-desktop.png'});
  await openProfile();
  await fillProfileInput('Business name', 'Browser test business');
  await fillProfileInput('Business phone (optional)', '9876543210');
  await page.getByRole('button',{name:'Save Profile',exact:true}).click();
  await page.getByText(/^Saved ✓/).waitFor();
  await page.screenshot({path:'web-profile-saved.png'});
  await returnHomeFromProfile();
  await page.reload({waitUntil:'domcontentloaded', timeout:60000});
  await enableSemantics();
  await text('Active: Timeline').waitFor();
  await page.setViewportSize({width:390, height:844});
  await page.screenshot({path:'web-dashboard-mobile.png'});
  await text('Accounts').click();
  await record().waitFor();
  assert.match(await record().getAttribute('aria-label'), /Opening: ₹100\.00/);
  await page.setViewportSize({width:1280, height:900});
  await page.screenshot({path: 'web-desktop.png'});
  await page.setViewportSize({width: 390, height: 844});
  await page.screenshot({path: 'web-mobile.png'});
  await page.getByRole('button', {name:'Back', exact:true}).click();
  await text('Active: Timeline').waitFor();
  await page.waitForFunction(() => navigator.serviceWorker.controller !== null, null, {timeout:60000});
  await context.setOffline(true);
  await page.reload({waitUntil:'domcontentloaded', timeout:60000});
  await enableSemantics();
  await text('Active: Timeline').waitFor();
  await text('Accounts').click(); await record().waitFor();
  assert.match(await record().getAttribute('aria-label'), /Opening: ₹100\.00/);
  await context.close();
  context = await chromium.launchPersistentContext(profile, {...options, offline:true});
  page = await context.newPage(); observe();
  await page.goto('http://127.0.0.1:8080', {waitUntil:'domcontentloaded', timeout:60000});
  await enableSemantics();
  await text('Active: Timeline').waitFor();
  await text('Accounts').click(); await record().waitFor();
  assert.match(await record().getAttribute('aria-label'), /Opening: ₹100\.00/);
  await page.screenshot({path:'web-offline-cold-start.png'});
  await page.getByRole('button',{name:'Back',exact:true}).click();
  await text('Active: Timeline').waitFor();
  await openProfile();
  await focusProfileInput('Business name');
  await checkProfileInput('Business name', 'Browser test business');
  await focusProfileInput('Business phone (optional)');
  await checkProfileInput('Business phone (optional)', '+919876543210');
  await page.keyboard.press('Tab');
  await page.screenshot({path:'web-profile-offline-cold-start.png'});
  await returnHomeFromProfile();
  await page.getByRole('button', {name:'Settings',exact:true}).first().click();
  await text('Backup & Restore').click();
  const passphrase = page.getByLabel('Backup passphrase', {exact:true});
  await passphrase.click();
  await passphrase.press('Home');
  await passphrase.fill('Browser acceptance backup passphrase');
  await checkProfileInput('Backup passphrase', 'Browser acceptance backup passphrase');
  await text('Enable encrypted checkpoints for this browser session').click();
  // The accessibility node also includes the saved IST timestamp.
  await page.getByText(/^Encrypted checkpoint saved on this device\b/).waitFor({timeout:60000});
  await text('Review / Restore device checkpoint').click();
  await text('Latest checkpoint').click();
  await text('Replace current financial records?').waitFor({timeout:60000});
  await text('Replace records').click();
  await page.locator('flt-semantics-host').getByText(/^Records restored successfully/).first().waitFor({timeout:60000});
  await page.screenshot({path:'web-backup-restored-offline.png'});
  await page.getByRole('button', {name:'Back',exact:true}).click();
  await page.getByRole('button', {name:'Back',exact:true}).click();
  await text('Accounts').click();
  await record().waitFor();
  assert.match(await record().getAttribute('aria-label'), /Opening: ₹100\.00/);
  assert.deepEqual(errors, [], 'Browser runtime must have no unhandled page errors');
  console.log('PASS: startup, IndexedDB account persistence, dashboard switching, desktop/mobile rendering, offline reload and cold start, business profile persistence and offline encrypted checkpoint restore');
  } finally {
    if (!page.isClosed()) await page.screenshot({path: 'web-final-state.png'});
    fs.writeFileSync('web-runtime.log', diagnostic.concat(errors).join('\n'));
    if (!page.isClosed()) fs.writeFileSync('web-dom.html', await page.content());
    await context.close();
    fs.rmSync(profile, {recursive:true, force:true});
  }
})().catch(error => { console.error(error); process.exit(1); });
