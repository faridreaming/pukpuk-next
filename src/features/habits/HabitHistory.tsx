import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { shiftDaysLocal } from '@/lib/date'

async function fetchHistory(habitId: string) {
  const from = shiftDaysLocal(29)
  const { data, error } = await supabase
    .from('check_ins')
    .select('tanggal, status')
    .eq('habit_id', habitId)
    .gte('tanggal', from)
  if (error) throw error
  return data
}

function buildDays(
  createdAt: string,
  records: { tanggal: string; status: string }[],
) {
  const map = new Map(records.map((r) => [r.tanggal, r.status]))
  const createdDate = createdAt.slice(0, 10)
  const days: { date: string; status: string }[] = []

  for (let i = 29; i >= 0; i--) {
    const key = shiftDaysLocal(i)
    days.push({
      date: key,
      status: key < createdDate ? 'future' : (map.get(key) ?? 'none'),
    })
  }
  return days
}

const COLOR: Record<string, string> = {
  berhasil: 'var(--pukpuk-moss)',
  gagal: 'var(--pukpuk-brick)',
  none: 'var(--pukpuk-ash)',
  future: 'transparent',
}

export function HabitHistory({
  habitId,
  createdAt,
}: {
  habitId: string
  createdAt: string
}) {
  const { data, isLoading } = useQuery({
    queryKey: ['history', habitId],
    queryFn: () => fetchHistory(habitId),
  })
  if (isLoading || !data) return null
  const days = buildDays(createdAt, data)

  return (
    <div className="mt-3 flex flex-wrap gap-1">
      {days.map((d) => (
        <div
          key={d.date}
          title={`${d.date}: ${d.status}`}
          className="h-2.5 w-2.5 rounded-sm"
          style={{ backgroundColor: COLOR[d.status] }}
        />
      ))}
    </div>
  )
}
