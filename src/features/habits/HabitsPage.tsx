import { useEffect } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router'
import { Button } from '@/components/ui/button'
import { supabase } from '@/lib/supabase'
import { useCheckIn } from './useCheckIn'

async function fetchHabits() {
  const { data, error } = await supabase
    .from('habits')
    .select('*, habit_stages(*)')
  if (error) throw error
  return data
}

async function fetchTodayCheckIns() {
  const today = new Date().toISOString().slice(0, 10)
  const { data, error } = await supabase
    .from('check_ins')
    .select('habit_id, status')
    .eq('tanggal', today)
  if (error) throw error
  return new Map(data.map((c) => [c.habit_id, c.status]))
}

function HabitRow({ habit }: { habit: any }) {
  const queryClient = useQueryClient()
  const { requestCheckIn } = useCheckIn(habit.id)
  const { data: todayMap } = useQuery({
    queryKey: ['today-checkins'],
    queryFn: fetchTodayCheckIns,
  })
  const sudahCheckIn = todayMap?.has(habit.id)

  async function handleRestart() {
    const { error } = await supabase.rpc('restart_habit', {
      p_habit_id: habit.id,
    })
    if (!error) queryClient.invalidateQueries({ queryKey: ['habits'] })
  }

  return (
    <li className="flex items-center justify-between border-b py-3">
      <span>
        {habit.nama} — stage {habit.stage_saat_ini} · nyawa{' '}
        {habit.nyawa_tersisa}
        {habit.status === 'maintenance' && ' · maintenance'}
        {habit.status === 'paused' && ' · paused'}
      </span>

      {habit.status === 'paused' ? (
        <Button size="sm" variant="outline" onClick={handleRestart}>
          Restart
        </Button>
      ) : (
        <div className="flex gap-2">
          <Button
            size="sm"
            disabled={sudahCheckIn}
            onClick={() => requestCheckIn('berhasil')}
          >
            Berhasil
          </Button>
          <Button
            size="sm"
            variant="outline"
            disabled={sudahCheckIn}
            onClick={() => requestCheckIn('gagal')}
          >
            Gagal
          </Button>
        </div>
      )}
    </li>
  )
}

export function HabitsPage() {
  const queryClient = useQueryClient()

  useEffect(() => {
    supabase.rpc('evaluate_all_habits_lazy').then(() => {
      queryClient.invalidateQueries({ queryKey: ['habits'] })
    })
  }, [queryClient])

  const { data: habits, isLoading } = useQuery({
    queryKey: ['habits'],
    queryFn: fetchHabits,
  })

  if (isLoading) return <p>Memuat habit...</p>

  return (
    <div className="p-4">
      <div className="mb-4 flex items-center justify-between">
        <h1 className="text-xl font-semibold">Habit kamu</h1>
        <Link to="/habits/new">
          <Button>Tambah Habit</Button>
        </Link>
      </div>
      {habits?.length === 0 && <p>Belum ada habit.</p>}
      <ul>
        {habits?.map((h) => (
          <HabitRow key={h.id} habit={h} />
        ))}
      </ul>
    </div>
  )
}
