import { expect, onboard, rp, test } from './fixtures'

test.describe('Onboarding', () => {
  test('welcome screen explains the app and starts setup', async ({ page }) => {
    await page.goto('/')
    await expect(page.getByRole('heading', { name: /Know where every/ })).toBeVisible()
    await expect(page.getByText('Log it in 3 seconds')).toBeVisible()
    await expect(page.getByText('Works offline')).toBeVisible()
    await expect(page.getByText('Private by design')).toBeVisible()
    await page.getByRole('button', { name: 'Get started' }).click()
    await expect(page.getByRole('heading', { name: 'Where’s your money?' })).toBeVisible()
  })

  test('Cash, BCA and GoPay are pre-selected; credit card is optional', async ({ page }) => {
    await page.goto('/')
    await page.getByRole('button', { name: 'Get started' }).click()
    await expect(page.getByRole('checkbox', { name: 'Use Cash' })).toHaveAttribute('aria-checked', 'true')
    await expect(page.getByRole('checkbox', { name: 'Use BCA' })).toHaveAttribute('aria-checked', 'true')
    await expect(page.getByRole('checkbox', { name: 'Use GoPay' })).toHaveAttribute('aria-checked', 'true')
    await expect(page.getByRole('checkbox', { name: 'Use Credit card' })).toHaveAttribute('aria-checked', 'false')
    await page.getByRole('checkbox', { name: 'Use Credit card' }).click()
    await expect(page.getByRole('button', { name: 'Create 4 accounts' })).toBeEnabled()
  })

  test('cannot finish with no accounts selected', async ({ page }) => {
    await page.goto('/')
    await page.getByRole('button', { name: 'Get started' }).click()
    for (const name of ['Cash', 'BCA', 'GoPay']) await page.getByRole('checkbox', { name: `Use ${name}` }).click()
    await expect(page.getByRole('button', { name: 'Choose at least one' })).toBeDisabled()
  })

  test('starting balances add up to net worth on Overview', async ({ page }) => {
    await onboard(page, { cash: 250_000, bca: 5_000_000, gopay: 150_000 })
    const worth = page.getByRole('link', { name: /Net worth/ })
    await expect(worth).toContainText(rp(5_400_000))
    await expect(worth).toContainText('Cash')
    await expect(worth).toContainText('BCA')
    await expect(worth).toContainText('GoPay')
    await expect(page.getByText('No transactions yet')).toBeVisible()
  })

  test('setup runs only once; a reload goes straight to Overview', async ({ page }) => {
    await onboard(page)
    await page.reload()
    await expect(page.getByRole('heading', { level: 1, name: 'Overview' })).toBeVisible()
    await expect(page.getByRole('button', { name: 'Get started' })).toHaveCount(0)
  })

  test('"I already use Duit" skips setup and opens sync', async ({ page }) => {
    await page.goto('/')
    await page.getByRole('button', { name: /I already use Duit on another device/ }).click()
    await expect(page.getByRole('heading', { level: 1, name: 'Sync & backup' })).toBeVisible()
    await expect(page.getByLabel('Project URL')).toBeVisible()
  })
})
