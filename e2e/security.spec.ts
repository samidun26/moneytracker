import type { CDPSession, Page } from '@playwright/test'
import { expect, expectToast, goTo, onboard, test } from './fixtures'

const PIN = '246810'

async function openAppLock(page: Page) {
  await goTo(page, 'More')
  await page.getByRole('link', { name: /App lock/ }).click()
  await expect(page.getByRole('heading', { level: 1, name: 'App lock' })).toBeVisible()
}

/** Taps a PIN on whichever PIN pad is showing (setup sheet or lock screen). */
async function enterPin(scope: ReturnType<Page['locator']> | Page, pin: string) {
  for (const d of pin) await scope.getByRole('button', { name: d, exact: true }).click()
}

async function turnOnLock(page: Page) {
  await openAppLock(page)
  await page.getByRole('switch', { name: 'Require unlock' }).click()
  const sheet = page.getByRole('dialog', { name: 'Set PIN' })
  await expect(sheet.getByText('Choose a 6-digit PIN')).toBeVisible()
  await enterPin(sheet, PIN)
  await expect(sheet.getByText('Confirm your PIN')).toBeVisible()
  await enterPin(sheet, PIN)
  await expectToast(page, 'App lock is on')
}

/** A virtual passkey authenticator that behaves like Face ID with a successful scan. */
async function addFaceId(page: Page): Promise<{ cdp: CDPSession; authenticatorId: string }> {
  const cdp = await page.context().newCDPSession(page)
  await cdp.send('WebAuthn.enable')
  const { authenticatorId } = await cdp.send('WebAuthn.addVirtualAuthenticator', {
    options: { protocol: 'ctap2', transport: 'internal', hasResidentKey: true, hasUserVerification: true, isUserVerified: true, automaticPresenceSimulation: true },
  })
  return { cdp, authenticatorId }
}

test.describe('App lock', () => {
  test.beforeEach(async ({ page }) => {
    await onboard(page, { cash: 750_000 })
  })

  test('turning on the lock asks for a 6-digit PIN twice', async ({ page }) => {
    await turnOnLock(page)
    await expect(page.getByRole('switch', { name: 'Require unlock' })).toHaveAttribute('aria-checked', 'true')
    await expect(page.getByRole('combobox', { name: 'Lock after' })).toBeVisible()
    await goTo(page, 'More')
    await expect(page.getByRole('link', { name: /App lock/ })).toContainText('PIN')
  })

  test('mismatched confirmation starts over', async ({ page }) => {
    await openAppLock(page)
    await page.getByRole('switch', { name: 'Require unlock' }).click()
    const sheet = page.getByRole('dialog', { name: 'Set PIN' })
    await enterPin(sheet, PIN)
    await expect(sheet.getByText('Confirm your PIN')).toBeVisible()
    await enterPin(sheet, '111111')
    await expect(sheet.getByText('PINs didn’t match. Try again.')).toBeVisible()
    await expect(sheet.getByText('Choose a 6-digit PIN')).toBeVisible()
    await sheet.getByRole('button', { name: 'Cancel' }).click()
    await expect(page.getByRole('switch', { name: 'Require unlock' })).toHaveAttribute('aria-checked', 'false')
  })

  test('opening the app shows the lock screen; the right PIN unlocks it', async ({ page }) => {
    await turnOnLock(page)
    await page.reload()
    const lock = page.getByRole('dialog', { name: 'Duit is locked' })
    await expect(lock.getByText('Enter PIN')).toBeVisible()
    await enterPin(lock, '000000')
    await expect(lock).toBeVisible()
    await expect(lock.getByRole('status')).toHaveAttribute('aria-label', '0 of 6 digits entered') // dots clear after a wrong PIN
    await enterPin(lock, PIN)
    await expect(lock).toHaveCount(0)
    await expect(page.getByRole('heading', { level: 1, name: 'App lock' })).toBeVisible()
  })

  test('five wrong PINs trigger a cooldown', async ({ page }) => {
    await turnOnLock(page)
    await page.reload()
    const lock = page.getByRole('dialog', { name: 'Duit is locked' })
    for (let i = 0; i < 5; i++) {
      await enterPin(lock, '999999')
      await expect(lock.getByRole('status')).toHaveAttribute('aria-label', '0 of 6 digits entered')
    }
    await expect(lock.getByText(/Try again in 30s/)).toBeVisible()
    await expect(lock.getByRole('button', { name: '1', exact: true })).toBeDisabled()
  })

  test('change PIN: the new one works, the old one does not', async ({ page }) => {
    await turnOnLock(page)
    await page.getByRole('button', { name: 'Change PIN' }).click()
    const sheet = page.getByRole('dialog', { name: 'Set PIN' })
    await enterPin(sheet, '135791')
    await expect(sheet.getByText('Confirm your PIN')).toBeVisible()
    await enterPin(sheet, '135791')
    await expectToast(page, 'PIN changed')
    await page.reload()
    const lock = page.getByRole('dialog', { name: 'Duit is locked' })
    await enterPin(lock, PIN)
    await expect(lock).toBeVisible()
    await expect(lock.getByRole('status')).toHaveAttribute('aria-label', '0 of 6 digits entered')
    await enterPin(lock, '135791')
    await expect(lock).toHaveCount(0)
  })

  test('turning the lock off removes the lock screen', async ({ page }) => {
    await turnOnLock(page)
    await page.getByRole('switch', { name: 'Require unlock' }).click()
    await expect(page.getByRole('switch', { name: 'Require unlock' })).toHaveAttribute('aria-checked', 'false')
    await page.reload()
    await expect(page.getByRole('heading', { level: 1, name: 'App lock' })).toBeVisible()
    await expect(page.getByRole('dialog', { name: 'Duit is locked' })).toHaveCount(0)
  })

  test('Face ID: set up with a passkey, then it unlocks without the PIN', async ({ page, browserName }) => {
    test.skip(browserName !== 'chromium', 'virtual authenticators are a Chromium DevTools feature')
    await addFaceId(page)
    await turnOnLock(page)
    const bio = page.getByRole('switch', { name: /^Unlock with / })
    await expect(bio).toBeEnabled()
    await bio.click()
    await expectToast(page, / is on$/)
    await expect(bio).toHaveAttribute('aria-checked', 'true')
    await page.reload()
    // The lock screen asks for Face ID straight away; the passkey answers, so it opens by itself.
    await expect(page.getByRole('heading', { level: 1, name: 'App lock' })).toBeVisible()
    await expect(page.getByRole('dialog', { name: 'Duit is locked' })).toHaveCount(0)
  })

  test('a failed Face ID scan keeps the app locked; the PIN still works', async ({ page, browserName }) => {
    test.skip(browserName !== 'chromium', 'virtual authenticators are a Chromium DevTools feature')
    const { cdp, authenticatorId } = await addFaceId(page)
    await turnOnLock(page)
    await page.getByRole('switch', { name: /^Unlock with / }).click()
    await expectToast(page, / is on$/)
    // From now on the "face" doesn't match: the passkey refuses user verification.
    await cdp.send('WebAuthn.setUserVerified', { authenticatorId, isUserVerified: false })
    await page.reload()
    const lock = page.getByRole('dialog', { name: 'Duit is locked' })
    await expect(lock).toBeVisible()
    await expect(lock.getByRole('button', { name: 'Unlock with Face ID' })).toBeVisible()
    await enterPin(lock, PIN)
    await expect(lock).toHaveCount(0)
  })
})
