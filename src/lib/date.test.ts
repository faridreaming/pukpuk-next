import { describe, it, expect } from 'vitest'
import { dateToLocalString, shiftDaysLocal } from './date'

describe('date utils', () => {
  it('dateToLocalString pakai komponen tanggal LOKAL, bukan UTC', () => {
    // jam 2 pagi waktu lokal -- kalau pakai toISOString() polos,
    // ini bisa "geser" ke hari sebelumnya kalau timezone di depan UTC
    const d = new Date(2026, 6, 14, 2, 0, 0) // bulan index 6 = Juli
    expect(dateToLocalString(d)).toBe('2026-07-14')
  })

  it('shiftDaysLocal(0) sama dengan hari ini', () => {
    expect(shiftDaysLocal(0)).toBe(dateToLocalString(new Date()))
  })
})
