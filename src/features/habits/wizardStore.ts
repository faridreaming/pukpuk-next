import { create } from 'zustand'
import { generateLinearStages } from './generateStages'

interface WizardState {
  step: number
  nama: string
  targetAkhirNilai: number
  targetAkhirUnit: string
  jumlahStage: number
  stageTargets: number[]
  setNama: (v: string) => void
  setTargetAkhirNilai: (v: number) => void
  setTargetAkhirUnit: (v: string) => void
  setJumlahStage: (v: number) => void
  setStageTarget: (index: number, v: number) => void
  regenerateStages: () => void
  nextStep: () => void
  prevStep: () => void
  reset: () => void
}

const initialState = {
  step: 1,
  nama: '',
  targetAkhirNilai: 0,
  targetAkhirUnit: '',
  jumlahStage: 5,
  stageTargets: [] as number[],
}

export const useWizardStore = create<WizardState>((set, get) => ({
  ...initialState,
  setNama: (v) => set({ nama: v }),
  setTargetAkhirNilai: (v) => set({ targetAkhirNilai: v }),
  setTargetAkhirUnit: (v) => set({ targetAkhirUnit: v }),
  setJumlahStage: (v) => set({ jumlahStage: v }),
  setStageTarget: (index, v) =>
    set((state) => {
      const next = [...state.stageTargets]
      next[index] = v
      return { stageTargets: next }
    }),
  regenerateStages: () => {
    const { targetAkhirNilai, jumlahStage } = get()
    set({ stageTargets: generateLinearStages(targetAkhirNilai, jumlahStage) })
  },
  nextStep: () => set((s) => ({ step: s.step + 1 })),
  prevStep: () => set((s) => ({ step: Math.max(1, s.step - 1) })),
  reset: () => set(initialState),
}))
