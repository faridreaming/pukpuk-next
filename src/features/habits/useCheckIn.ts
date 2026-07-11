import { useRef } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { toast } from 'sonner'
import { supabase } from '@/lib/supabase'

export function useCheckIn(habitId: string) {
  const queryClient = useQueryClient()
  const pendingRef = useRef<{
    timeoutId: number
    toastId: string | number
  } | null>(null)

  async function commit(
    status: 'berhasil' | 'gagal',
    onEvent?: (event: string) => void,
  ) {
    const { data, error } = await supabase.rpc('create_check_in', {
      p_habit_id: habitId,
      p_status: status,
    })
    if (error) {
      toast.error('Gagal menyimpan check-in')
      return
    }
    queryClient.invalidateQueries({ queryKey: ['habits'] })
    onEvent?.(data.event)
    if (data.event === 'stage_up') toast.success('Naik ke stage berikutnya')
    if (data.event === 'endgame')
      toast.success('Target akhir tercapai — masuk maintenance')
  }

  function requestCheckIn(
    status: 'berhasil' | 'gagal',
    onEvent?: (event: string) => void,
  ) {
    if (pendingRef.current) {
      clearTimeout(pendingRef.current.timeoutId)
      toast.dismiss(pendingRef.current.toastId)
    }

    const timeoutId = window.setTimeout(() => {
      pendingRef.current = null
      commit(status, onEvent)
    }, 5000)

    const toastId = toast(
      status === 'berhasil' ? 'Check-in: berhasil' : 'Check-in: gagal',
      {
        duration: 5000,
        action: {
          label: 'Undo',
          onClick: () => {
            clearTimeout(timeoutId)
            pendingRef.current = null
          },
        },
      },
    )

    pendingRef.current = { timeoutId, toastId }
  }

  return { requestCheckIn }
}
