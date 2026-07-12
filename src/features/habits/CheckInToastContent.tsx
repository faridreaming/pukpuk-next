import { useEffect, useRef } from 'react'

export function CheckInToastContent({ label }: { label: string }) {
  const barRef = useRef<HTMLDivElement>(null)
  const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches

  useEffect(() => {
    const el = barRef.current
    if (!el || reduced) return
    requestAnimationFrame(() => {
      el.style.transition = 'width 5000ms linear'
      el.style.width = '0%'
    })
  }, [reduced])

  return (
    <div className="flex w-full flex-col gap-1.5">
      <span>{label}</span>
      <div
        className="h-0.5 w-full overflow-hidden rounded-full"
        style={{ backgroundColor: 'rgba(237,234,227,0.2)' }}
      >
        <div
          ref={barRef}
          className="h-full"
          style={{
            width: reduced ? '0%' : '100%',
            backgroundColor: 'var(--pukpuk-ember)',
          }}
        />
      </div>
    </div>
  )
}
