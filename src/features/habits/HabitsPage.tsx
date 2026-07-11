import { useEffect } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

async function fetchHabits() {
  const { data, error } = await supabase
    .from('habits')
    .select('*, habit_stages(*)')
  if (error) throw error
  return data
}

export function HabitsPage() {
  const queryClient = useQueryClient()

  // evaluasi lazy dulu tiap kali halaman dibuka, baru fetch data terbaru
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
    <div>
      <h1>Habit kamu</h1>
      {habits?.length === 0 && <p>Belum ada habit. Yuk bikin satu.</p>}
      <ul>
        {habits?.map((h) => (
          <li key={h.id}>
            {h.nama} — stage {h.stage_saat_ini} · nyawa {h.nyawa_tersisa}
          </li>
        ))}
      </ul>
    </div>
  )
}
