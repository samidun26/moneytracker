/**
 * IDR money helpers. Amounts are always stored as positive integer rupiah;
 * the transaction type carries the sign.
 */
const plain = new Intl.NumberFormat('id-ID', { maximumFractionDigits: 0 })
const compact = new Intl.NumberFormat('id-ID', { notation: 'compact', maximumFractionDigits: 1 })

const MINUS = '−' // typographic minus, same width as plus

export const MAX_AMOUNT = 999_999_999_999 // < 1 trillion rupiah

/** 150000 → "150.000" */
export function formatNumber(n: number): string {
  return plain.format(Math.round(Math.abs(n)))
}

/** 150000 → "Rp 150.000", -150000 → "−Rp 150.000" */
export function formatRp(n: number): string {
  const s = `Rp ${formatNumber(n)}`
  return n < 0 ? MINUS + s : s
}

/** 1250000 → "1,3 jt", 150000 → "150 rb" (Indonesian compact units) */
export function formatCompact(n: number): string {
  const s = compact.format(Math.abs(n)).replace(/ /g, ' ')
  return n < 0 ? MINUS + s : s
}

/** "Rp 1,3 jt" */
export function formatRpCompact(n: number): string {
  const s = `Rp ${formatCompact(Math.abs(n))}`
  return n < 0 ? MINUS + s : s
}

/** Signed display for a flow: +8.500.000 / −45.000 */
export function formatSigned(n: number): string {
  if (n === 0) return '0'
  return (n > 0 ? '+' : MINUS) + formatNumber(n)
}

/** Keep digits only and clamp: "Rp 12.500" → 12500 */
export function parseAmount(input: string): number {
  const digits = input.replace(/\D/g, '')
  if (!digits) return 0
  return Math.min(Number(digits), MAX_AMOUNT)
}

/** Parse a signed amount (for opening balances): "-1.500.000" → -1500000 */
export function parseSignedAmount(input: string): number {
  const negative = /^\s*[-−]/.test(input)
  const n = parseAmount(input)
  return negative ? -n : n
}
