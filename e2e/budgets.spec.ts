import type { Page } from '@playwright/test'
import { addTransaction, expect, expectToast, goTo, onboard, rp, test } from './fixtures'

async function openBudgets(page: Page) {
  await goTo(page, 'More')
  await page.getByRole('link', { name: /Budgets/ }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'Budgets' })).toBeVisible()
}

async function saveBudget(page: Page, amount: number, category?: string) {
  const sheet = page.getByRole('dialog', { name: /budget/ })
  if (category) {
    const select = sheet.locator('select[aria-label="Category"]')
    const value = await select.locator('option', { hasText: category }).first().getAttribute('value')
    await select.selectOption(value!)
  }
  await sheet.locator('#budget-amount').fill(String(amount))
  await sheet.getByRole('button', { name: 'Save' }).click()
  await expectToast(page, 'Budget saved')
}

test.describe('Budgets', () => {
  test.beforeEach(async ({ page }) => {
    await onboard(page, { cash: 2_000_000, bca: 10_000_000 })
  })

  test('set an overall monthly budget and see what is left', async ({ page }) => {
    await addTransaction(page, { amount: 400_000, category: 'Groceries', note: 'Superindo' })
    await openBudgets(page)
    await expect(page.getByText('No budgets yet')).toBeVisible()
    await page.getByRole('button', { name: 'Set overall budget' }).click()
    await saveBudget(page, 2_000_000)
    const card = page.getByRole('button', { name: /Overall budget/ })
    await expect(card).toContainText(rp(400_000))
    await expect(card).toContainText('of Rp 2 jt')
    await expect(card).toContainText(`${rp(1_600_000)} left`)
    // 1.600.000 over the 7 days left in September, including today
    await expect(card).toContainText('Rp 228,6 rb/day for 7 days')
  })

  test('Overview shows the budget once it exists', async ({ page }) => {
    await addTransaction(page, { amount: 100_000, category: 'Shopping' })
    await expect(page.getByRole('link', { name: /Set a monthly budget/ })).toBeVisible()
    await openBudgets(page)
    await page.getByRole('button', { name: 'Set overall budget' }).click()
    await saveBudget(page, 1_000_000)
    await goTo(page, 'Home')
    await expect(page.getByRole('heading', { level: 1, name: 'Overview' })).toBeVisible()
    await expect(page.getByRole('heading', { name: 'Budget', exact: true })).toBeVisible()
    await expect(page.getByText(`${rp(900_000)} left`)).toBeVisible()
  })

  test('a category budget warns at 80% and flags overspending', async ({ page }) => {
    await openBudgets(page)
    await page.getByRole('button', { name: 'Set overall budget' }).click()
    await saveBudget(page, 5_000_000)
    await page.getByRole('button', { name: /Coffee & Snacks/ }).click()
    await saveBudget(page, 100_000)
    const coffee = page.getByRole('button', { name: /Coffee & Snacks/ })
    await expect(coffee).toContainText('Rp 0 / Rp 100 rb')

    await addTransaction(page, { amount: 85_000, category: 'Coffee & Snacks' })
    await expect(coffee).toContainText('Rp 15 rb left')
    await expect(coffee.getByText('Rp 15 rb left')).toHaveClass(/text-warning/)

    await addTransaction(page, { amount: 35_000, category: 'Coffee & Snacks' })
    await expect(coffee).toContainText('Over by Rp 20 rb')
    await expect(coffee.getByText('Over by Rp 20 rb')).toHaveClass(/text-negative/)
  })

  test('edit a budget amount and remove it', async ({ page }) => {
    await openBudgets(page)
    await page.getByRole('button', { name: 'Set overall budget' }).click()
    await saveBudget(page, 3_000_000)
    await page.getByRole('button', { name: /Overall budget/ }).click()
    await saveBudget(page, 4_000_000)
    await expect(page.getByRole('button', { name: /Overall budget/ })).toContainText('of Rp 4 jt')
    await page.getByRole('button', { name: /Overall budget/ }).click()
    await page.getByRole('dialog').getByRole('button', { name: /Remove budget/ }).click()
    await expectToast(page, 'Budget removed')
    await expect(page.getByText('No budgets yet')).toBeVisible()
  })

  test('previous month has its own, empty spending', async ({ page }) => {
    await addTransaction(page, { amount: 250_000, category: 'Shopping' })
    await openBudgets(page)
    await page.getByRole('button', { name: 'Set overall budget' }).click()
    await saveBudget(page, 1_000_000)
    await page.getByRole('button', { name: 'Previous month' }).click()
    await expect(page.getByRole('button', { name: 'August 2026' })).toBeVisible()
    await expect(page.getByRole('button', { name: /Overall budget/ })).toContainText('Rp 0')
    await expect(page.getByRole('button', { name: 'Next month' })).toBeEnabled()
    await page.getByRole('button', { name: 'Next month' }).click()
    await expect(page.getByRole('button', { name: /Overall budget/ })).toContainText(rp(250_000))
    await expect(page.getByRole('button', { name: 'Next month' })).toBeDisabled()
  })
})
