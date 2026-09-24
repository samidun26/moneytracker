/**
 * Light haptic tick. Android: Vibration API. iOS Safari has no Vibration API,
 * but toggling a native `<input type="checkbox" switch>` (iOS 18+) plays the
 * system haptic — a well-known progressive enhancement. No-ops elsewhere.
 */
let label: HTMLLabelElement | null = null

export function haptic(): void {
  try {
    if ('vibrate' in navigator && typeof navigator.vibrate === 'function' && !/iPhone|iPad/.test(navigator.userAgent)) {
      navigator.vibrate(8)
      return
    }
    if (!label) {
      const id = 'duit-haptic'
      const input = document.createElement('input')
      input.type = 'checkbox'
      input.id = id
      input.setAttribute('switch', '')
      input.setAttribute('aria-hidden', 'true')
      input.tabIndex = -1
      label = document.createElement('label')
      label.htmlFor = id
      label.setAttribute('aria-hidden', 'true')
      for (const el of [input, label]) {
        el.style.cssText = 'position:fixed;width:1px;height:1px;opacity:0;pointer-events:none;left:-99px;top:0'
        document.body.appendChild(el)
      }
    }
    label.click()
  } catch {
    /* ignore */
  }
}
