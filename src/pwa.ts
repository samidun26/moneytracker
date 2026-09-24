import { registerSW } from 'virtual:pwa-register'

/** Service worker: precaches the app shell so Duit opens instantly and offline. Auto-updates. */
export function registerServiceWorker(): void {
  if (!('serviceWorker' in navigator) || import.meta.env.DEV) return
  registerSW({
    immediate: true,
    onRegisteredSW(_url, reg) {
      // Check for a new version whenever the app returns to the foreground.
      document.addEventListener('visibilitychange', () => {
        if (document.visibilityState === 'visible') void reg?.update()
      })
    },
  })
}
