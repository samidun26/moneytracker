import { ensureSeeded } from '@/db/seed'
import { postDueRecurring } from '@/domain/recurringActions'
import { startSync } from '@/sync/engine'

/**
 * Startup sequence. Seeding and the UI never wait on the network; the first
 * sync gets a short head start before recurring items post, so two devices
 * don't race to log the same bill.
 */
export async function bootstrap(): Promise<void> {
  await ensureSeeded()
  void navigator.storage?.persist?.().catch(() => {})
  const firstSync = startSync().catch(() => {})
  await Promise.race([firstSync, new Promise((r) => setTimeout(r, 3000))])
  await postDueRecurring()
  // Re-check recurring when the app comes back to the foreground on a new day.
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') void postDueRecurring()
  })
}
