import { Check, X, RotateCcw, PauseCircle, Sparkles } from 'lucide-react'
import { useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { Button } from '@/components/ui/button'
import { supabase } from '@/lib/supabase'
import { useCheckIn } from './useCheckIn'
import { StageTrack } from './StageTrack'
import { Archive } from 'lucide-react'

const DURASI_HARI = 7 // samain dengan konstanta di RPC create_check_in

export function HabitCard({
  habit,
  sudahCheckIn,
}: {
  habit: any
  sudahCheckIn: boolean
}) {
  const queryClient = useQueryClient()
  const { requestCheckIn, isPending } = useCheckIn(habit.id)
  const [lastEvent, setLastEvent] = useState<
    'stage_up' | 'endgame' | 'progress' | 'none'
  >('none')

  const currentStage = habit.habit_stages?.find(
    (s: any) => s.stage_number === habit.stage_saat_ini,
  )

  async function handleRestart() {
    const { error } = await supabase.rpc('restart_habit', {
      p_habit_id: habit.id,
    })
    if (!error) queryClient.invalidateQueries({ queryKey: ['habits'] })
  }

  async function handleArchive() {
    const confirmed = window.confirm(
      `Arsipkan "${habit.nama}"? Riwayat check-in tetap tersimpan, tapi habit ini nggak muncul lagi di daftar.`,
    )
    if (!confirmed) return
    const { error } = await supabase.rpc('archive_habit', {
      p_habit_id: habit.id,
    })
    if (!error) queryClient.invalidateQueries({ queryKey: ['habits'] })
  }

  return (
    <div
      className="habit-card rounded-xl border p-4"
      style={{
        borderColor: 'var(--pukpuk-ash)',
        backgroundColor: 'var(--pukpuk-panel)',
      }}
    >
      <div className="mb-3 flex items-center justify-between">
        <h3
          className="font-medium"
          style={{ color: 'var(--pukpuk-parchment)' }}
        >
          {habit.nama}
        </h3>
        <div className="flex items-center gap-2">
          {habit.status === 'maintenance' && (
            <span
              className="flex items-center gap-1 text-xs"
              style={{ color: 'var(--pukpuk-moss)' }}
            >
              <Sparkles className="h-3 w-3" /> maintenance
            </span>
          )}
          {habit.status === 'paused' && (
            <span
              className="flex items-center gap-1 text-xs"
              style={{ color: 'var(--pukpuk-brick)' }}
            >
              <PauseCircle className="h-3 w-3" /> paused
            </span>
          )}
          <Button
            size="icon"
            variant="ghost"
            onClick={handleArchive}
            title="Arsipkan habit"
          >
            <Archive className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {habit.status !== 'paused' && (
        <StageTrack
          jumlahStage={habit.habit_stages?.length ?? 1}
          stageSaatIni={habit.stage_saat_ini}
          nyawaTersisa={habit.nyawa_tersisa}
          nyawaMaks={currentStage?.nyawa_maks ?? 3}
          progressHariSukses={habit.progress_hari_sukses}
          durasiHari={DURASI_HARI}
          event={lastEvent}
        />
      )}

      <div className="mt-4 flex gap-2">
        {habit.status === 'paused' ? (
          <Button size="sm" variant="outline" onClick={handleRestart}>
            <RotateCcw className="mr-1 h-4 w-4" /> Restart
          </Button>
        ) : habit.status === 'active' ? (
          <>
            <Button
              size="sm"
              disabled={sudahCheckIn || isPending}
              onClick={() => {
                setLastEvent('none')
                requestCheckIn('berhasil', (e) => setLastEvent(e as any))
              }}
            >
              <Check className="mr-1 h-4 w-4" /> Berhasil
            </Button>
            <Button
              size="sm"
              variant="outline"
              disabled={sudahCheckIn || isPending}
              onClick={() => requestCheckIn('gagal')}
            >
              <X className="mr-1 h-4 w-4" /> Gagal
            </Button>
          </>
        ) : null}
      </div>
    </div>
  )
}
