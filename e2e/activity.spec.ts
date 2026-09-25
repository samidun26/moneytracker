import { addTransaction, expect, goTo, onboard, test, txRow } from './fixtures'

test.describe('Activity: search, filter, grouping', () => {
  test.beforeEach(async ({ page }) => {
    await onboard(page, { cash: 1_000_000, bca: 10_000_000, gopay: 500_000 })
    await addTransaction(page, { amount: 32_000, category: 'Coffee & Snacks', note: 'Kopi Kenangan', account: 'GoPay' })
    await addTransaction(page, { amount: 25_000, category: 'Food & Drinks', note: 'Mie Ayam', account: 'Cash', yesterday: true })
    await addTransaction(page, { amount: 15_000, category: 'Transport', note: 'Gojek', account: 'GoPay' })
    await addTransaction(page, { type: 'income', amount: 3_200_000, category: 'Freelance', note: 'Logo design', account: 'BCA' })
    await addTransaction(page, { type: 'transfer', amount: 100_000, from: 'BCA', to: 'GoPay', note: 'Top up' })
    await goTo(page, 'Activity')
    await expect(page.getByRole('heading', { level: 1, name: 'Activity' })).toBeVisible()
  })

  test('groups by day, newest first, with a daily net', async ({ page }) => {
    const days = page.getByRole('heading', { level: 4 })
    await expect(days).toHaveText(['Today', 'Yesterday'])
    const today = page.locator('section').filter({ has: page.getByRole('heading', { level: 4, name: 'Today' }) })
    await expect(today).toContainText('+3.153.000') // 3.200.000 − 32.000 − 15.000; transfers don't count
    const yesterday = page.locator('section').filter({ has: page.getByRole('heading', { level: 4, name: 'Yesterday' }) })
    await expect(yesterday).toContainText('−25.000')
    await expect(yesterday).toContainText('Mie Ayam')
  })

  test('search matches notes, categories, accounts and amounts', async ({ page }) => {
    const search = page.getByRole('searchbox', { name: 'Search notes, categories, amounts' })
    await search.fill('kopi')
    await expect(txRow(page, 'Kopi Kenangan')).toBeVisible()
    await expect(txRow(page, 'Mie Ayam')).toHaveCount(0)
    await expect(page.getByText('1 result · −32.000')).toBeVisible()

    await search.fill('transport')
    await expect(txRow(page, 'Gojek')).toBeVisible()
    await expect(page.getByText(/^1 result/)).toBeVisible()

    await search.fill('gopay')
    await expect(page.getByText(/^3 results/)).toBeVisible() // Kopi, Gojek, and the top-up into GoPay

    await search.fill('25.000')
    await expect(txRow(page, 'Mie Ayam')).toBeVisible()
    await expect(page.getByText(/^1 result/)).toBeVisible()
  })

  test('no matches shows a helpful empty state, and clear resets', async ({ page }) => {
    const search = page.getByRole('searchbox', { name: 'Search notes, categories, amounts' })
    await search.fill('sushi')
    await expect(page.getByText('No matches')).toBeVisible()
    await page.getByRole('button', { name: 'Clear search' }).click()
    await expect(search).toHaveValue('')
    await expect(txRow(page, 'Kopi Kenangan')).toBeVisible()
  })

  test('filters by type', async ({ page }) => {
    const filter = page.getByRole('radiogroup', { name: 'Filter' })
    await filter.getByRole('radio', { name: 'Income' }).click()
    await expect(txRow(page, 'Logo design')).toBeVisible()
    await expect(txRow(page, 'Kopi Kenangan')).toHaveCount(0)
    await expect(page.getByText('1 result · +3.200.000')).toBeVisible()

    await filter.getByRole('radio', { name: 'Expenses' }).click()
    await expect(page.getByText('3 results · −72.000')).toBeVisible()
    await expect(txRow(page, 'Logo design')).toHaveCount(0)

    await filter.getByRole('radio', { name: 'Transfers' }).click()
    await expect(txRow(page, 'Top up')).toContainText('BCA → GoPay')
    await expect(page.getByText(/^1 result$/)).toBeVisible()

    await filter.getByRole('radio', { name: 'All' }).click()
    await expect(page.getByRole('heading', { level: 4 })).toHaveText(['Today', 'Yesterday'])
  })
})
