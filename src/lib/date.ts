export function dateToLocalString(d: Date): string {
  const year = d.getFullYear()
  const month = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

export function todayLocalDateString(): string {
  return dateToLocalString(new Date())
}

export function shiftDaysLocal(daysAgo: number): string {
  const d = new Date()
  d.setDate(d.getDate() - daysAgo)
  return dateToLocalString(d)
}
