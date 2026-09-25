import type { ColorName } from '@/db/types'

/** Resolves to a CSS variable so category colors adapt to light/dark. */
export function colorVar(name: ColorName | string): string {
  return `var(--sys-${name}, var(--sys-gray))`
}

/** Soft background for emoji badges. */
export function colorSoft(name: ColorName | string, pct = 18): string {
  return `color-mix(in srgb, ${colorVar(name)} ${pct}%, transparent)`
}
