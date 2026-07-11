import { useNavigate } from 'react-router'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { supabase } from '@/lib/supabase'
import { useWizardStore } from './wizardStore'

export function CreateHabitWizard() {
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const wizard = useWizardStore()

  const createHabit = useMutation({
    mutationFn: async () => {
      const { data, error } = await supabase.rpc('create_habit_with_stages', {
        p_nama: wizard.nama,
        p_target_akhir_nilai: wizard.targetAkhirNilai,
        p_target_akhir_unit: wizard.targetAkhirUnit,
        p_stage_targets: wizard.stageTargets,
      })
      if (error) throw error
      return data
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['habits'] })
      wizard.reset()
      navigate('/')
    },
  })

  if (wizard.step === 1) {
    return (
      <div className="space-y-3 p-4">
        <h1 className="text-xl font-semibold">Habit baru</h1>
        <Input
          placeholder="nama habit, mis. meditasi"
          value={wizard.nama}
          onChange={(e) => wizard.setNama(e.target.value)}
        />
        <Input
          type="number"
          placeholder="target akhir"
          value={wizard.targetAkhirNilai || ''}
          onChange={(e) => wizard.setTargetAkhirNilai(Number(e.target.value))}
        />
        <Input
          placeholder="satuan, mis. menit"
          value={wizard.targetAkhirUnit}
          onChange={(e) => wizard.setTargetAkhirUnit(e.target.value)}
        />
        <Input
          type="number"
          placeholder="jumlah stage"
          value={wizard.jumlahStage}
          onChange={(e) => wizard.setJumlahStage(Number(e.target.value))}
        />
        <Button
          onClick={() => {
            wizard.regenerateStages()
            wizard.nextStep()
          }}
          disabled={
            !wizard.nama || !wizard.targetAkhirNilai || !wizard.targetAkhirUnit
          }
        >
          Lanjut
        </Button>
      </div>
    )
  }

  if (wizard.step === 2) {
    return (
      <div className="space-y-3 p-4">
        <h1 className="text-xl font-semibold">Preview stage</h1>
        <p className="text-sm text-muted-foreground">
          Boleh diedit manual kalau mau.
        </p>
        {wizard.stageTargets.map((val, i) => (
          <div key={i} className="flex items-center gap-2">
            <span className="w-16">Stage {i + 1}</span>
            <Input
              type="number"
              value={val}
              onChange={(e) => wizard.setStageTarget(i, Number(e.target.value))}
            />
            <span>{wizard.targetAkhirUnit}</span>
          </div>
        ))}
        <div className="flex gap-2">
          <Button variant="outline" onClick={wizard.prevStep}>
            Kembali
          </Button>
          <Button onClick={wizard.nextStep}>Lanjut</Button>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-3 p-4">
      <h1 className="text-xl font-semibold">Konfirmasi</h1>
      <p>
        {wizard.nama} — target akhir {wizard.targetAkhirNilai}{' '}
        {wizard.targetAkhirUnit}
      </p>
      <ul className="text-sm">
        {wizard.stageTargets.map((val, i) => (
          <li key={i}>
            Stage {i + 1}: {val} {wizard.targetAkhirUnit}
          </li>
        ))}
      </ul>
      <div className="flex gap-2">
        <Button variant="outline" onClick={wizard.prevStep}>
          Kembali
        </Button>
        <Button
          onClick={() => createHabit.mutate()}
          disabled={createHabit.isPending}
        >
          {createHabit.isPending ? 'Menyimpan...' : 'Buat Habit'}
        </Button>
      </div>
      {createHabit.isError && (
        <p className="text-sm text-red-500">Gagal, coba lagi.</p>
      )}
    </div>
  )
}
