import { describe, expect, it } from 'vitest'
import { applyKey } from './Keypad'

describe('amount keypad', () => {
  it('builds rupiah amounts digit by digit', () => {
    let a = 0
    for (const k of ['2', '5'] as const) a = applyKey(a, k)
    expect(a).toBe(25)
    expect(applyKey(a, '000')).toBe(25_000)
  })

  it('ignores leading zeros and a 000 on an empty amount', () => {
    expect(applyKey(0, '0')).toBe(0)
    expect(applyKey(0, '000')).toBe(0)
  })

  it('deletes the last digit, and clear resets', () => {
    expect(applyKey(25_000, 'back')).toBe(2_500)
    expect(applyKey(7, 'back')).toBe(0)
    expect(applyKey(0, 'back')).toBe(0)
    expect(applyKey(25_000, 'clear')).toBe(0)
  })

  it('refuses to go past the maximum instead of overflowing', () => {
    expect(applyKey(999_999_999_999, '1')).toBe(999_999_999_999)
    expect(applyKey(999_999_999, '000')).toBe(999_999_999_000)
    expect(applyKey(9_999_999_999, '000')).toBe(9_999_999_999)
  })
})
