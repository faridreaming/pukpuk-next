import { useEffect, useRef } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Link } from 'react-router'
import gsap from 'gsap'
import { Button } from '@/components/ui/button'
import { supabase } from '@/lib/supabase'
import { HabitCard } from './HabitCard'
import { Plus, Target } from 'lucide-react'
import { Skeleton } from '@/components/ui/skeleton'
import { LogOut } from 'lucide-react'

async function fetchHabits() {
  const { data, error } = await supabase
    .from('habits')
    .select('*, habit_stages!habit_id(*)')
    .neq('status', 'archived')
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

async function handleLogout() {
  await supabase.auth.signOut()
}

export function HabitsPage() {
  const queryClient = useQueryClient()
  const listRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    supabase.rpc('evaluate_all_habits_lazy').then(() => {
      queryClient.invalidateQueries({ queryKey: ['habits'] })
    })
  }, [queryClient])

  const {
    data: habits,
    isLoading,
    isError,
    error,
  } = useQuery({ queryKey: ['habits'], queryFn: fetchHabits })

  const { data: todaySet } = useQuery({
    queryKey: ['today-checkins'],
    queryFn: fetchTodayCheckIns,
  })

  const hasAnimatedRef = useRef(false)

  useEffect(() => {
    if (!listRef.current || !habits?.length || hasAnimatedRef.current) return
    hasAnimatedRef.current = true
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

  if (isLoading) {
    return (
      <div className="mx-auto max-w-xl space-y-3 p-4">
        {[1, 2, 3].map((i) => (
          <div
            key={i}
            className="rounded-xl border p-4"
            style={{
              borderColor: 'var(--pukpuk-ash)',
              backgroundColor: 'var(--pukpuk-panel)',
            }}
          >
            <Skeleton className="mb-3 h-5 w-1/3 bg-[var(--pukpuk-ash)]" />
            <Skeleton className="mb-2 h-3 w-full bg-[var(--pukpuk-ash)]" />
            <Skeleton className="h-1 w-full bg-[var(--pukpuk-ash)]" />
          </div>
        ))}
      </div>
    )
  }
  if (isError)
    return (
      <p className="p-4 text-sm" style={{ color: 'var(--pukpuk-brick)' }}>
        Gagal memuat habit: {(error as Error).message}
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
        <div className="flex items-center gap-2">
          <Link to="/habits/new">
            <Button size="sm">
              <Plus className="mr-1 h-4 w-4" /> Tambah Habit
            </Button>
          </Link>
          <Button
            size="sm"
            variant="ghost"
            onClick={handleLogout}
            title="Keluar"
          >
            <LogOut className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {habits?.length === 0 && (
        <div
          className="flex flex-col items-center gap-3 rounded-xl border border-dashed p-8 text-center"
          style={{ borderColor: 'var(--pukpuk-ash)' }}
        >
          <Target
            className="h-8 w-8"
            style={{ color: 'var(--pukpuk-ember)' }}
          />
          <p
            className="text-sm"
            style={{ color: 'var(--pukpuk-parchment)', opacity: 0.6 }}
          >
            Belum ada habit. Mulai satu buat lihat progresnya di sini.
          </p>
        </div>
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
