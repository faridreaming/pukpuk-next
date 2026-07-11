export function generateLinearStages(
  targetAkhir: number,
  jumlahStage: number,
): number[] {
  const stages: number[] = []
  for (let i = 1; i <= jumlahStage; i++) {
    stages.push(
      i === jumlahStage
        ? targetAkhir // stage terakhir SELALU persis target akhir, hindari rounding error
        : Math.round(((targetAkhir * i) / jumlahStage) * 100) / 100,
    )
  }
  return stages
}
