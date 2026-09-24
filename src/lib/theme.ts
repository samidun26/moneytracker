import { readString, writeString } from './storage'

export type ThemePref = 'system' | 'light' | 'dark'
const KEY = 'duit.theme'

export function getThemePref(): ThemePref {
  const v = readString(KEY)
  return v === 'light' || v === 'dark' ? v : 'system'
}

/** Applies the theme to <html> and keeps the iOS status-bar color in sync. */
export function applyTheme(pref: ThemePref = getThemePref()): void {
  const root = document.documentElement
  if (pref === 'system') root.removeAttribute('data-theme')
  else root.setAttribute('data-theme', pref)
  const metas = document.querySelectorAll<HTMLMetaElement>('meta[name="theme-color"]')
  metas.forEach((m) => {
    const media = m.getAttribute('data-media') ?? m.media
    m.setAttribute('data-media', media)
    if (pref === 'system') {
      m.media = media
      m.content = media.includes('dark') ? '#000000' : '#F2F2F7'
    } else {
      m.media = ''
      m.content = pref === 'dark' ? '#000000' : '#F2F2F7'
    }
  })
}

export function setThemePref(pref: ThemePref): void {
  writeString(KEY, pref === 'system' ? null : pref)
  applyTheme(pref)
}
