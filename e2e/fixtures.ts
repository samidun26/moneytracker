import { test as base, expect, type Locator, type Page } from '@playwright/test'

/** Every test runs on Thursday 24 September 2026, 10:00 in Jakarta, so dates and month totals are predictable. */
export const NOW = new Date('2026-09-24T10:00:00+07:00')
export const TODAY = '2026-09-24'

export const test = base.extend({
  page: async ({ page }, use) => {
    await page.clock.setFixedTime(NOW)
    await use(page)
  },
})

export { expect }

export function isDesktop(page: Page): boolean {
  return (page.viewportSize()?.width ?? 0) >= 768
}

/** "Rp 1.250.000" style, as the app prints it. */
export function rp(n: number): string {
  const s = `Rp ${Math.abs(n).toLocaleString('id-ID')}`
  return n < 0 ? `−${s}` : s
}

// ── Onboarding ──────────────────────────────────────────────────────────────

/** First run: welcome → accounts (Cash, BCA, GoPay) with optional balances → Overview. */
export async function onboard(page: Page, balances: { cash?: number; bca?: number; gopay?: number } = {}) {
  await page.goto('/')
  await page.getByRole('button', { name: 'Get started' }).click()
  const amounts = page.locator('input[inputmode="numeric"]')
  const order = [balances.cash, balances.bca, balances.gopay]
  for (let i = 0; i < order.length; i++) {
    if (order[i]) await amounts.nth(i).fill(String(order[i]))
  }
  await page.getByRole('button', { name: 'Create 3 accounts' }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Overview' })).toBeVisible()
}

// ── Composer ────────────────────────────────────────────────────────────────

export async function openComposer(page: Page): Promise<Locator> {
  await page.getByRole('button', { name: /^Add transaction/ }).filter({ visible: true }).first().click()
  const sheet = page.getByRole('dialog')
  await expect(sheet.getByRole('radiogroup', { name: 'Transaction type' })).toBeVisible()
  return sheet
}

/** Types an amount on the on-screen keypad, one key per digit. */
export async function typeAmount(sheet: Locator, amount: number) {
  const pad = sheet.getByRole('group', { name: 'Amount keypad' })
  for (const ch of String(amount)) await pad.getByRole('button', { name: ch, exact: true }).click()
}

/** The big "Rp 25.000" readout at the top of the composer. */
export function amountDisplay(sheet: Locator): Locator {
  return sheet.locator('div[aria-live="polite"]').first()
}

async function pickOption(select: Locator, text: string) {
  const value = await select.locator('option', { hasText: text }).first().getAttribute('value')
  await select.selectOption(value!)
}

export interface TxInput {
  type?: 'expense' | 'income' | 'transfer'
  amount: number
  category?: string
  note?: string
  account?: string
  from?: string
  to?: string
  yesterday?: boolean
}

/** Adds a transaction through the composer and waits for the "Saved" toast. */
export async function addTransaction(page: Page, t: TxInput) {
  const sheet = await openComposer(page)
  const type = t.type ?? 'expense'
  if (type !== 'expense') {
    await sheet.getByRole('radiogroup', { name: 'Transaction type' }).getByRole('radio', { name: type === 'income' ? 'Income' : 'Transfer' }).click()
  }
  await typeAmount(sheet, t.amount)
  if (type === 'transfer') {
    if (t.from) await pickOption(sheet.locator('select[aria-label="From"]'), t.from)
    if (t.to) await pickOption(sheet.locator('select[aria-label="To"]'), t.to)
  } else {
    await sheet.getByRole('radiogroup', { name: 'Category' }).getByRole('radio', { name: t.category ?? (type === 'income' ? 'Salary' : 'Food & Drinks'), exact: true }).click()
    if (t.account) await pickOption(sheet.locator('select[aria-label="Account"]'), t.account)
  }
  if (t.yesterday) await sheet.getByRole('button', { name: 'Yesterday' }).click()
  if (t.note) {
    // With the note focused, phones hide the keypad for the keyboard; its "done" key saves.
    const note = sheet.getByPlaceholder('Add a note (e.g. Kopi Kenangan)')
    await note.fill(t.note)
    await note.press('Enter')
  } else {
    await sheet.getByRole('button', { name: 'Save', exact: true }).click()
  }
  await expectToast(page, `Saved · ${rp(t.amount)}`)
  await expect(page.getByRole('dialog')).toHaveCount(0)
}

// ── Common UI ───────────────────────────────────────────────────────────────

export async function expectToast(page: Page, text: string | RegExp) {
  await expect(page.getByRole('status').filter({ hasText: text })).toBeVisible()
}

/** Main navigation: tab bar on phones, sidebar on desktop. */
export async function goTo(page: Page, tab: 'Home' | 'Activity' | 'Insights' | 'More') {
  await page.getByRole('link', { name: tab, exact: true }).filter({ visible: true }).first().click()
}

/** Rows in the transaction lists are buttons: "<title> <subtitle> −25.000". */
export function txRow(page: Page, title: string): Locator {
  return page.locator('main button').filter({ hasText: title })
}
