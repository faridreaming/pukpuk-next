import { useEffect, useRef } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router'
import gsap from 'gsap'
import { Button } from '@/components/ui/button'
import { supabase } from '@/lib/supabase'
import { HabitCard } from './HabitCard'

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
    .select('habit_id')
    .eq('tanggal', today)
  if (error) throw error
  return new Set(data.map((c) => c.habit_id))
}

export function HabitsPage() {
  const queryClient = useQueryClient()
  const listRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    supabase.rpc('evaluate_all_habits_lazy').then(() => {
      queryClient.invalidateQueries({ queryKey: ['habits'] })
    })
  }, [queryClient])

  const { data: habits, isLoading } = useQuery({
    queryKey: ['habits'],
    queryFn: fetchHabits,
  })
  const { data: todaySet } = useQuery({
    queryKey: ['today-checkins'],
    queryFn: fetchTodayCheckIns,
  })

  useEffect(() => {
    if (!listRef.current || !habits?.length) return
    const reduced = window.matchMedia(
      '(prefers-reduced-motion: reduce)',
    ).matches
    gsap.fromTo(
      listRef.current.querySelectorAll('.habit-card'),
      { opacity: 0, y: reduced ? 0 : 12 },
      {
        opacity: 1,
        y: 0,
        duration: reduced ? 0 : 0.4,
        stagger: reduced ? 0 : 0.06,
      },
    )
  }, [habits])

  if (isLoading)
    return (
      <p className="p-4" style={{ color: 'var(--pukpuk-parchment)' }}>
        Memuat habit...
      </p>
    )

  return (
    <div className="mx-auto max-w-xl p-4">
      <div className="mb-6 flex items-center justify-between">
        <h1
          className="text-lg font-medium"
          style={{ color: 'var(--pukpuk-parchment)' }}
        >
          Habit kamu
        </h1>
        <Link to="/habits/new">
          <Button size="sm">Tambah Habit</Button>
        </Link>
      </div>

      {habits?.length === 0 && (
        <p
          className="text-sm"
          style={{ color: 'var(--pukpuk-parchment)', opacity: 0.6 }}
        >
          Belum ada habit. Mulai satu buat lihat progresnya di sini.
        </p>
      )}

      <div ref={listRef} className="space-y-3">
        {habits?.map((h) => (
          <HabitCard
            key={h.id}
            habit={h}
            sudahCheckIn={todaySet?.has(h.id) ?? false}
          />
        ))}
      </div>
    </div>
  )
}
