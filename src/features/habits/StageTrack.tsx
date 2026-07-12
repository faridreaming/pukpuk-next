import { useEffect, useRef } from 'react'
import gsap from 'gsap'

interface StageTrackProps {
  jumlahStage: number
  stageSaatIni: number
  nyawaTersisa: number
  nyawaMaks: number
  progressHariSukses: number
  durasiHari: number
  event?: 'stage_up' | 'endgame' | 'progress' | 'none'
}

export function StageTrack({
  jumlahStage,
  stageSaatIni,
  nyawaTersisa,
  nyawaMaks,
  progressHariSukses,
  durasiHari,
  event,
}: StageTrackProps) {
  const nodeRefs = useRef<(HTMLDivElement | null)[]>([])
  const fillRef = useRef<HTMLDivElement | null>(null)
  const prefersReducedMotion =
    typeof window !== 'undefined' &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches

  useEffect(() => {
    if (
      prefersReducedMotion ||
      !event ||
      event === 'none' ||
      event === 'progress'
    )
      return
    const currentNode = nodeRefs.current[stageSaatIni - 1]

    if (event === 'stage_up' && currentNode) {
      gsap.fromTo(
        currentNode,
        { scale: 0.5 },
        { scale: 1, duration: 0.45, ease: 'back.out(2.5)' },
      )
      if (fillRef.current) {
        const ratio =
          jumlahStage > 1 ? (stageSaatIni - 1) / (jumlahStage - 1) : 1
        gsap.to(fillRef.current, {
          scaleX: ratio,
          duration: 0.5,
          ease: 'power2.out',
        })
      }
    }

    if (event === 'endgame') {
      gsap.to(nodeRefs.current.filter(Boolean), {
        backgroundColor: 'var(--pukpuk-moss)',
        borderColor: 'var(--pukpuk-moss)',
        stagger: 0.06,
        duration: 0.3,
      })
    }
  }, [event, stageSaatIni, jumlahStage, prefersReducedMotion])

  const fillRatio = jumlahStage > 1 ? (stageSaatIni - 1) / (jumlahStage - 1) : 1

  return (
    <div className="space-y-2">
      <div className="relative flex h-3 w-full items-center">
        <div className="absolute left-0 right-0 h-[2px] bg-[var(--pukpuk-ash)]" />
        <div
          ref={fillRef}
          className="absolute left-0 h-[2px] origin-left bg-[var(--pukpuk-ember)]"
          style={{ width: '100%', transform: `scaleX(${fillRatio})` }}
        />
        <div className="relative flex w-full justify-between">
          {Array.from({ length: jumlahStage }).map((_, i) => {
            const stageNum = i + 1
            const reached = stageNum <= stageSaatIni
            return (
              <div
                key={i}
                ref={(el) => {
                  nodeRefs.current[i] = el
                }}
                className="h-3 w-3 rounded-full border-2"
                style={{
                  backgroundColor: reached
                    ? 'var(--pukpuk-ember)'
                    : 'var(--pukpuk-panel)',
                  borderColor: reached
                    ? 'var(--pukpuk-ember)'
                    : 'var(--pukpuk-ash)',
                }}
                title={`Stage ${stageNum}`}
              />
            )
          })}
        </div>
      </div>

      <div
        className="flex items-center justify-between font-mono-stage text-xs"
        style={{ color: 'var(--pukpuk-parchment)', opacity: 0.7 }}
      >
        <span>
          stage {stageSaatIni}/{jumlahStage}
        </span>
        <div className="flex gap-1">
          {Array.from({ length: nyawaMaks }).map((_, i) => (
            <span
              key={i}
              className="h-2 w-2 rounded-full transition-colors duration-300"
              style={{
                backgroundColor:
                  i < nyawaTersisa
                    ? 'var(--pukpuk-brick)'
                    : 'var(--pukpuk-ash)',
              }}
            />
          ))}
        </div>
      </div>

      <div
        className="h-1 w-full overflow-hidden rounded-full"
        style={{ backgroundColor: 'var(--pukpuk-ash)' }}
      >
        <div
          className="h-full transition-[width] duration-300"
          style={{
            width: `${Math.min(100, (progressHariSukses / durasiHari) * 100)}%`,
            backgroundColor: 'var(--pukpuk-moss)',
          }}
        />
      </div>
    </div>
  )
}
