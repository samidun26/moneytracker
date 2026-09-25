import { describe, expect, it } from 'vitest'
import { addMonthsClamped, diffDays, formatDayLabel, monthBounds, ordinal, shiftMonth } from './dates'

describe('dates', () => {
  it('clamps month-end dates', () => {
    expect(addMonthsClamped('2026-01-31', 1)).toBe('2026-02-28')
    expect(addMonthsClamped('2028-01-31', 1)).toBe('2028-02-29')
    expect(addMonthsClamped('2026-02-28', 1, 31)).toBe('2026-03-31')
    expect(addMonthsClamped('2026-11-15', 3)).toBe('2027-02-15')
    expect(addMonthsClamped('2026-03-15', -3)).toBe('2025-12-15')
  })
  it('shifts months and computes bounds', () => {
    expect(shiftMonth('2026-01', -1)).toBe('2025-12')
    expect(monthBounds('2026-02')).toEqual({ start: '2026-02-01', end: '2026-02-28', days: 28 })
  })
  it('labels days relative to today', () => {
    expect(formatDayLabel('2026-09-24', '2026-09-24')).toBe('Today')
    expect(formatDayLabel('2026-09-23', '2026-09-24')).toBe('Yesterday')
    expect(formatDayLabel('2026-09-20', '2026-09-24')).toBe('Sun, 20 Sep')
    expect(diffDays('2026-09-24', '2026-10-01')).toBe(7)
  })
  it('ordinals', () => {
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 25].map(ordinal)).toEqual([
      '1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd', '25th',
    ])
  })
})
