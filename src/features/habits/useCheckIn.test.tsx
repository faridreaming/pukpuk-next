import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { renderHook, act } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import { useCheckIn } from './useCheckIn'

vi.mock('@/lib/supabase', () => ({
  supabase: { rpc: vi.fn() },
}))
vi.mock('sonner', () => ({
  toast: Object.assign(
    vi.fn(() => 'toast-id'),
    { success: vi.fn(), error: vi.fn(), dismiss: vi.fn() },
  ),
}))

import { supabase } from '@/lib/supabase'
import { toast } from 'sonner'

function createWrapper() {
  const queryClient = new QueryClient()
  const Wrapper = ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  )
  return { Wrapper, queryClient }
}

describe('useCheckIn', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    vi.clearAllMocks()
    ;(supabase.rpc as any).mockResolvedValue({
      data: { event: 'progress' },
      error: null,
    })
  })
  afterEach(() => vi.useRealTimers())

  it('TIDAK langsung manggil create_check_in saat requestCheckIn dipanggil', () => {
    const { Wrapper } = createWrapper()
    const { result } = renderHook(() => useCheckIn('habit-1'), {
      wrapper: Wrapper,
    })
    act(() => result.current.requestCheckIn('berhasil'))
    expect(supabase.rpc).not.toHaveBeenCalled()
  })

  it('manggil create_check_in SETELAH 5 detik', async () => {
    const { Wrapper } = createWrapper()
    const { result } = renderHook(() => useCheckIn('habit-1'), {
      wrapper: Wrapper,
    })
    act(() => result.current.requestCheckIn('berhasil'))
    await act(async () => {
      vi.advanceTimersByTime(5000)
    })
    expect(supabase.rpc).toHaveBeenCalledWith('create_check_in', {
      p_habit_id: 'habit-1',
      p_status: 'berhasil',
    })
  })

  it('TIDAK manggil create_check_in sama sekali kalau Undo diklik sebelum 5 detik', () => {
    const { Wrapper } = createWrapper()
    const { result } = renderHook(() => useCheckIn('habit-1'), {
      wrapper: Wrapper,
    })
    act(() => result.current.requestCheckIn('berhasil'))

    const undoOnClick = (toast as any).mock.calls[0][1].action.onClick
    act(() => undoOnClick())
    act(() => vi.advanceTimersByTime(5000))

    expect(supabase.rpc).not.toHaveBeenCalled()
  })

  it('check-in kedua sebelum yang pertama commit MEMBATALKAN yang pertama, bukan dobel', () => {
    const { Wrapper } = createWrapper()
    const { result } = renderHook(() => useCheckIn('habit-1'), {
      wrapper: Wrapper,
    })
    act(() => result.current.requestCheckIn('berhasil'))
    act(() => vi.advanceTimersByTime(2000))
    act(() => result.current.requestCheckIn('gagal')) // ganti pikiran

    act(() => vi.advanceTimersByTime(5000))

    expect(supabase.rpc).toHaveBeenCalledTimes(1)
    expect(supabase.rpc).toHaveBeenCalledWith('create_check_in', {
      p_habit_id: 'habit-1',
      p_status: 'gagal',
    })
  })

  it('menginvalidasi query today-checkins juga, bukan cuma habits', async () => {
    const { Wrapper, queryClient } = createWrapper()
    const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries')
    const { result } = renderHook(() => useCheckIn('habit-1'), {
      wrapper: Wrapper,
    })

    act(() => result.current.requestCheckIn('berhasil'))
    await act(async () => {
      vi.advanceTimersByTime(5000)
    })

    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['today-checkins'] })
  })
})
