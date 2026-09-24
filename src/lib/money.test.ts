import { describe, expect, it } from 'vitest'
import { formatCompact, formatRp, formatSigned, parseAmount, parseSignedAmount } from './money'

describe('money', () => {
  it('formats IDR with dot thousands separators and no decimals', () => {
    expect(formatRp(150000)).toBe('Rp 150.000')
    expect(formatRp(8_500_000)).toBe('Rp 8.500.000')
    expect(formatRp(-45000)).toBe('−Rp 45.000')
    expect(formatRp(0)).toBe('Rp 0')
  })
  it('uses Indonesian compact units', () => {
    expect(formatCompact(150_000)).toBe('150 rb')
    expect(formatCompact(1_250_000)).toBe('1,3 jt')
    expect(formatCompact(2_000_000_000)).toBe('2 M')
  })
  it('signs flows', () => {
    expect(formatSigned(8_500_000)).toBe('+8.500.000')
    expect(formatSigned(-45_000)).toBe('−45.000')
  })
  it('parses user input', () => {
    expect(parseAmount('Rp 12.500')).toBe(12500)
    expect(parseAmount('')).toBe(0)
    expect(parseAmount('99999999999999')).toBe(999_999_999_999)
    expect(parseSignedAmount('-1.500.000')).toBe(-1_500_000)
    expect(parseSignedAmount('−2.000')).toBe(-2000)
  })
})
