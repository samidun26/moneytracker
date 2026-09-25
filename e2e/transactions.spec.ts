import { addTransaction, amountDisplay, expect, expectToast, goTo, isDesktop, onboard, openComposer, rp, test, txRow, typeAmount } from './fixtures'

test.describe('Adding transactions', () => {
  test.beforeEach(async ({ page }) => {
    await onboard(page, { cash: 500_000, bca: 5_000_000, gopay: 200_000 })
  })

  test('logs an expense with category, note and account', async ({ page }) => {
    await addTransaction(page, { amount: 25_000, category: 'Food & Drinks', note: 'Mie Ayam', account: 'Cash' })
    const row = txRow(page, 'Mie Ayam')
    await expect(row).toContainText('Food & Drinks · Cash')
    await expect(row).toContainText('−25.000')
    await expect(page.getByText(`Spent in September`).locator('..')).toContainText(rp(25_000))
    await expect(page.getByRole('link', { name: /Net worth/ })).toContainText(rp(5_675_000))
  })

  test('logs income in green with a plus sign', async ({ page }) => {
    await addTransaction(page, { type: 'income', amount: 16_500_000, category: 'Salary', note: 'Gaji September', account: 'BCA' })
    const row = txRow(page, 'Gaji September')
    await expect(row).toContainText('+16.500.000')
    await expect(row.getByText('+16.500.000')).toHaveClass(/text-positive/)
    await expect(page.getByRole('link', { name: /Net worth/ })).toContainText(rp(22_200_000))
  })

  test('a transfer moves money between accounts without counting as spending', async ({ page }) => {
    await addTransaction(page, { type: 'transfer', amount: 100_000, from: 'BCA', to: 'GoPay', note: 'Top up GoPay' })
    await expect(txRow(page, 'Top up GoPay')).toContainText('BCA → GoPay')
    await expect(page.getByRole('link', { name: /Net worth/ })).toContainText(rp(5_700_000))
    await expect(page.getByText('Spent in September').locator('..')).toContainText('Rp 0')
    await page.getByRole('link', { name: /Net worth/ }).click()
    await expect(page.getByRole('link', { name: /BCA/ })).toContainText(rp(4_900_000))
    await expect(page.getByRole('link', { name: /GoPay/ })).toContainText(rp(300_000))
  })

  test('keypad: 000 key, delete digit, and hold-to-clear', async ({ page }) => {
    const sheet = await openComposer(page)
    const pad = sheet.getByRole('group', { name: 'Amount keypad' })
    await pad.getByRole('button', { name: '2', exact: true }).click()
    await pad.getByRole('button', { name: '5', exact: true }).click()
    await pad.getByRole('button', { name: '000', exact: true }).click()
    await expect(amountDisplay(sheet)).toHaveText(/Rp\s*25\.000$/)
    await pad.getByRole('button', { name: /Delete digit/ }).click()
    await expect(amountDisplay(sheet)).toHaveText(/Rp\s*2\.500$/)
    const del = pad.getByRole('button', { name: /Delete digit/ })
    const box = (await del.boundingBox())!
    await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2)
    await page.mouse.down()
    await page.waitForTimeout(600)
    await page.mouse.up()
    await expect(amountDisplay(sheet)).toHaveText(/Rp\s*0$/)
  })

  test('will not save without an amount or a category', async ({ page }) => {
    const sheet = await openComposer(page)
    const save = sheet.getByRole('button', { name: 'Save', exact: true })
    await expect(save).toHaveAttribute('aria-disabled', 'true')
    await expect(save).toBeInViewport() // the sheet slides up first
    await save.click({ force: true })
    await expect(sheet).toBeVisible()
    await typeAmount(sheet, 15_000)
    const pick = sheet.getByRole('button', { name: 'Pick a category' })
    await expect(pick).toHaveAttribute('aria-disabled', 'true')
    await pick.click({ force: true })
    await expect(sheet).toBeVisible()
    await sheet.getByRole('radiogroup', { name: 'Category' }).getByRole('radio', { name: 'Transport', exact: true }).click()
    await expect(sheet.getByRole('button', { name: 'Save', exact: true })).toHaveAttribute('aria-disabled', 'false')
  })

  test('a transfer needs two different accounts', async ({ page }) => {
    const sheet = await openComposer(page)
    await sheet.getByRole('radio', { name: 'Transfer' }).click()
    await typeAmount(sheet, 50_000)
    const from = sheet.locator('select[aria-label="From"]')
    const to = sheet.locator('select[aria-label="To"]')
    await to.selectOption(await from.inputValue())
    await expect(sheet.getByRole('button', { name: 'Pick two different accounts' })).toBeVisible()
  })

  test('"Yesterday" dates the transaction to the previous day', async ({ page }) => {
    await addTransaction(page, { amount: 12_000, category: 'Coffee & Snacks', note: 'Kopi', yesterday: true })
    await goTo(page, 'Activity')
    await expect(page.getByRole('heading', { level: 4, name: 'Yesterday' })).toBeVisible()
  })

  test('cancel closes the composer without saving', async ({ page }) => {
    const sheet = await openComposer(page)
    await typeAmount(sheet, 99_000)
    await sheet.getByRole('button', { name: 'Cancel' }).click()
    await expect(page.getByRole('dialog')).toHaveCount(0)
    await expect(page.getByText('No transactions yet')).toBeVisible()
  })

  test('home-screen shortcut ?add=income opens the composer on Income', async ({ page }) => {
    await page.goto('/?add=income')
    const sheet = page.getByRole('dialog')
    await expect(sheet.getByRole('heading', { name: 'New income' })).toBeVisible()
    await expect(sheet.getByRole('radio', { name: 'Income' })).toHaveAttribute('aria-checked', 'true')
  })

  test('desktop: N opens the composer and the keyboard types the amount', async ({ page }) => {
    test.skip(!isDesktop(page), 'hardware keyboard shortcuts are a desktop feature')
    await page.keyboard.press('n')
    const sheet = page.getByRole('dialog')
    await expect(sheet.getByRole('heading', { name: 'New expense' })).toBeVisible()
    await page.keyboard.type('45000')
    await expect(amountDisplay(sheet)).toHaveText(/Rp\s*45\.000$/)
    await sheet.getByRole('radio', { name: 'Groceries', exact: true }).click()
    await page.keyboard.press('Enter')
    await expectToast(page, `Saved · ${rp(45_000)}`)
  })
})

test.describe('Editing and deleting', () => {
  test.beforeEach(async ({ page }) => {
    await onboard(page, { cash: 500_000 })
    await addTransaction(page, { amount: 32_000, category: 'Coffee & Snacks', note: 'Kopi Kenangan', account: 'Cash' })
  })

  test('tapping a transaction opens it for editing', async ({ page }) => {
    await txRow(page, 'Kopi Kenangan').click()
    const sheet = page.getByRole('dialog')
    await expect(sheet.getByRole('heading', { name: 'Edit expense' })).toBeVisible()
    await expect(amountDisplay(sheet)).toHaveText(/Rp\s*32\.000$/)
    await expect(sheet.getByRole('radio', { name: 'Coffee & Snacks', exact: true })).toHaveAttribute('aria-checked', 'true')
    for (let i = 0; i < 5; i++) await sheet.getByRole('button', { name: /Delete digit/ }).click()
    await typeAmount(sheet, 35_000)
    await sheet.getByRole('button', { name: 'Save', exact: true }).click()
    await expectToast(page, `Updated · ${rp(35_000)}`)
    await expect(txRow(page, 'Kopi Kenangan')).toContainText('−35.000')
    await expect(page.getByRole('link', { name: /Net worth/ })).toContainText(rp(465_000))
  })

  test('delete shows Undo, and Undo brings it back', async ({ page }) => {
    await txRow(page, 'Kopi Kenangan').click()
    await page.getByRole('dialog').getByRole('button', { name: 'Delete transaction' }).click()
    await expectToast(page, 'Transaction deleted')
    await expect(txRow(page, 'Kopi Kenangan')).toHaveCount(0)
    await expect(page.getByRole('link', { name: /Net worth/ })).toContainText(rp(500_000))
    await page.getByRole('status').getByRole('button', { name: 'Undo' }).click()
    await expect(txRow(page, 'Kopi Kenangan')).toBeVisible()
    await expect(page.getByRole('link', { name: /Net worth/ })).toContainText(rp(468_000))
  })

  test('changes survive a reload (saved on the device)', async ({ page }) => {
    await page.reload()
    await expect(txRow(page, 'Kopi Kenangan')).toContainText('−32.000')
  })
})
