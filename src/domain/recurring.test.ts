import { describe, expect, it } from 'vitest'
import { rule } from '@/test/factories'
import { describeSchedule, dueOccurrences, monthlyEquivalent, nextDueDate, occurrencesBetween, upcomingOccurrences } from './recurring'

describe('recurring', () => {
  it('keeps the anchor day for monthly rules across short months', () => {
    const r = rule({ startDate: '2026-01-31' })
    expect(occurrencesBetween(r, null, '2026-05-31')).toEqual([
      '2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30', '2026-05-31',
    ])
  })
  it('computes due occurrences after the last handled one', () => {
    const r = rule({ startDate: '2026-06-25', lastPostedDate: '2026-07-25' })
    expect(dueOccurrences(r, '2026-09-24')).toEqual(['2026-08-25'])
    expect(nextDueDate(r)).toBe('2026-08-25')
  })
  it('respects end date and paused rules', () => {
    const r = rule({ startDate: '2026-01-01', endDate: '2026-03-15' })
    expect(dueOccurrences(r, '2026-12-31')).toEqual(['2026-01-01', '2026-02-01', '2026-03-01'])
    expect(dueOccurrences({ ...r, active: false }, '2026-12-31')).toEqual([])
  })
  it('handles weekly intervals and long daily histories efficiently', () => {
    const w = rule({ frequency: 'weekly', interval: 2, startDate: '2026-09-01' })
    expect(occurrencesBetween(w, '2026-09-01', '2026-10-01')).toEqual(['2026-09-15', '2026-09-29'])
    const d = rule({ frequency: 'daily', startDate: '2020-01-01' })
    expect(occurrencesBetween(d, '2026-09-20', '2026-09-23')).toEqual(['2026-09-21', '2026-09-22', '2026-09-23'])
  })
  it('handles yearly rules on Feb 29', () => {
    const y = rule({ frequency: 'yearly', startDate: '2028-02-29' })
    expect(occurrencesBetween(y, null, '2033-01-01')).toEqual([
      '2028-02-29', '2029-02-28', '2030-02-28', '2031-02-28', '2032-02-29',
    ])
  })
  it('normalizes to a monthly cost', () => {
    expect(monthlyEquivalent({ amount: 120_000, frequency: 'yearly', interval: 1 })).toBe(10_000)
    expect(monthlyEquivalent({ amount: 100_000, frequency: 'weekly', interval: 1 })).toBe(433_333)
  })
  it('describes schedules in plain English', () => {
    expect(describeSchedule(rule({ startDate: '2026-09-25' }))).toBe('Monthly on the 25th')
    expect(describeSchedule(rule({ frequency: 'weekly', startDate: '2026-09-21' }))).toBe('Every Monday')
    expect(describeSchedule(rule({ frequency: 'daily', interval: 3 }))).toBe('Every 3 days')
  })
  it('lists due and upcoming items in date order', () => {
    const a = rule({ id: 'a', startDate: '2026-09-20', autoPost: false })
    const b = rule({ id: 'b', startDate: '2026-09-27' })
    const items = upcomingOccurrences([a, b], '2026-09-24', 7)
    expect(items.map((i) => [i.rule.id, i.date, i.status])).toEqual([
      ['a', '2026-09-20', 'due'],
      ['b', '2026-09-27', 'upcoming'],
    ])
  })
})
