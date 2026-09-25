import { readFile } from 'node:fs/promises'
import type { Page } from '@playwright/test'
import { addTransaction, expect, expectToast, goTo, onboard, rp, test, TODAY, txRow } from './fixtures'

async function openData(page: Page) {
  await goTo(page, 'More')
  await page.getByRole('link', { name: /Export & data/ }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Export & data' })).toBeVisible()
}

async function download(page: Page, row: RegExp) {
  const [file] = await Promise.all([page.waitForEvent('download'), page.getByRole('button', { name: row }).click()])
  return { name: file.suggestedFilename(), text: await readFile((await file.path())!, 'utf8') }
}

test.describe('Export, restore and erase', () => {
  test.beforeEach(async ({ page }) => {
    // Files go to a download, not the iOS share sheet, so the test can read them.
    await page.addInitScript(() => Object.defineProperty(navigator, 'canShare', { value: undefined }))
    await onboard(page, { cash: 1_000_000, gopay: 300_000 })
    await addTransaction(page, { amount: 32_000, category: 'Coffee & Snacks', note: 'Kopi "Kenangan", Mantan', account: 'GoPay' })
    await addTransaction(page, { type: 'income', amount: 2_500_000, category: 'Freelance', note: 'Logo design', account: 'BCA' })
  })

  test('CSV export has a header row and one row per transaction, with quoting', async ({ page }) => {
    await openData(page)
    await expect(page.getByRole('button', { name: /Transactions \(CSV\)/ })).toContainText('2 transactions')
    const csv = await download(page, /Transactions \(CSV\)/)
    expect(csv.name).toBe(`duit-transactions-${TODAY}.csv`)
    const lines = csv.text.split('\n')
    expect(lines[0]).toBe('Date,Type,Amount,Signed amount,Category,Account,To account,Note')
    expect(lines).toHaveLength(3)
    expect(csv.text).toContain(`${TODAY},expense,32000,-32000,Coffee & Snacks,GoPay,,"Kopi ""Kenangan"", Mantan"`)
    expect(csv.text).toContain(`${TODAY},income,2500000,2500000,Freelance,BCA,,Logo design`)
  })

  test('JSON backup contains every table', async ({ page }) => {
    await openData(page)
    const backup = await download(page, /Full backup \(JSON\)/)
    expect(backup.name).toBe(`duit-backup-${TODAY}.json`)
    const json = JSON.parse(backup.text)
    expect(json.app).toBe('duit')
    expect(json.version).toBe(1)
    expect(json.data.accounts).toHaveLength(3)
    expect(json.data.transactions).toHaveLength(2)
    expect(json.data.categories.length).toBeGreaterThan(20)
    expect(json.data.transactions[0]).not.toHaveProperty('dirty')
  })

  test('a backup restores everything on another device, and re-importing adds nothing', async ({ page, browser }) => {
    await openData(page)
    const backup = await download(page, /Full backup \(JSON\)/)

    // Another device (a laptop): a separate browser with empty storage.
    const fresh = await browser.newContext({ baseURL: test.info().project.use.baseURL, timezoneId: 'Asia/Jakarta', locale: 'en-US', serviceWorkers: 'block' })
    const other = await fresh.newPage()
    await other.clock.setFixedTime(new Date('2026-09-24T10:00:00+07:00'))
    await other.goto('/')
    await other.getByRole('button', { name: /I already use Duit on another device/ }).click()
    await other.goto('/more/data')
    const upload = other.locator('input[type="file"]')
    await upload.setInputFiles({ name: 'backup.json', mimeType: 'application/json', buffer: Buffer.from(backup.text) })
    await expectToast(other, /^Restored: \d+ added, 0 updated$/)

    await other.goto('/')
    await expect(other.getByRole('link', { name: /Net worth/ })).toContainText(rp(3_768_000))
    await expect(txRow(other, 'Logo design')).toContainText('+2.500.000')

    await other.goto('/more/data')
    await upload.setInputFiles({ name: 'backup.json', mimeType: 'application/json', buffer: Buffer.from(backup.text) })
    await expectToast(other, 'Restored: 0 added, 0 updated')
    await fresh.close()
  })

  test('restoring a file that is not a backup shows an error', async ({ page }) => {
    await openData(page)
    await page.locator('input[type="file"]').setInputFiles({ name: 'notes.json', mimeType: 'application/json', buffer: Buffer.from('{"hello":"world"}') })
    await expectToast(page, 'This file is not a Duit backup.')
    // Not JSON at all: same friendly message, never the parser's error text.
    await page.locator('input[type="file"]').setInputFiles({ name: 'photo.json', mimeType: 'application/json', buffer: Buffer.from('not json at all') })
    await expectToast(page, 'This file is not a Duit backup.')
    await expect(page.getByRole('status').filter({ hasText: /Unexpected|JSON/ })).toHaveCount(0)
  })

  test('erasing the device asks first, then returns to the welcome screen', async ({ page }) => {
    await openData(page)
    await page.getByRole('button', { name: 'Erase data on this device' }).click()
    const confirm = page.getByRole('alertdialog', { name: 'Erase all data on this device?' })
    await confirm.getByRole('button', { name: 'Cancel' }).click()
    await expect(confirm).toHaveCount(0)
    await expect(page.getByRole('heading', { level: 1, name: 'Export & data' })).toBeVisible()

    await page.getByRole('button', { name: 'Erase data on this device' }).click()
    await page.getByRole('alertdialog').getByRole('button', { name: 'Erase this device' }).click()
    await expect(page.getByRole('button', { name: 'Get started' })).toBeVisible()
  })
})
